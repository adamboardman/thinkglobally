package server

import (
	"errors"
	"fmt"
	"github.com/adamboardman/thinkglobally/store"
	jwt "github.com/appleboy/gin-jwt"
	"github.com/gin-gonic/contrib/static"
	"github.com/gin-gonic/gin"
	"net/http"
	"os"
	"strconv"
)

type WebApp struct {
	Router        *gin.Engine
	Store         *store.Store
	JwtMiddleware *jwt.GinJWTMiddleware
}

var App *WebApp

func (a *WebApp) Init(dbName string) {
	App = a
	a.Store = &store.Store{}
	a.Store.StoreInit("test-db")

	// Set the router as the default one shipped with Gin
	router := gin.Default()
	a.Router = router

	addWebAppStaticFiles(router)
	addApiRoutes(a, router)
	//addPhotoRoutes(a, router)
	addDefaultRouteToWebApp(router)
}

func addApiRoutes(a *WebApp, router *gin.Engine) {
	api := router.Group("/api")
	api.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "root of the API does nothing, next?"})
	})

	a.JwtMiddleware = a.InitAuth(api)
	api.GET("/users/:userID", a.JwtMiddleware.MiddlewareFunc(), LoadUser)
	//api.GET("/users/:userID/photo", a.JwtMiddleware.MiddlewareFunc(), UserPhoto)
	//api.POST("/users/:userID/photo", a.JwtMiddleware.MiddlewareFunc(), AddUserPhoto)
	//api.PUT("/users/:userID/photo", a.JwtMiddleware.MiddlewareFunc(), UpdateUserPhoto)
	api.PUT("/users/:userID", a.JwtMiddleware.MiddlewareFunc(), UpdateUser)
	api.GET("/concepts", ConceptsList)
	api.GET("/concepts/:conceptID", LoadConcept)
	api.GET("/concepts/:conceptID/tags", LoadConceptTags)
	api.POST("/concepts", a.JwtMiddleware.MiddlewareFunc(), AdminPermissionsRequired(), AddConcept)
	api.PUT("/concepts/:conceptID", a.JwtMiddleware.MiddlewareFunc(), AdminPermissionsRequired(), UpdateConcept)
	api.GET("/concept/:tag", FetchConcept)
	api.GET("/concept_tags", ConceptTagsList)
	api.POST("/concept_tags", a.JwtMiddleware.MiddlewareFunc(), AdminPermissionsRequired(), AddConceptTag)
	api.DELETE("/concept_tags/:conceptTagID", a.JwtMiddleware.MiddlewareFunc(), AdminPermissionsRequired(), DeleteConceptTag)
}

func AdminPermissionsRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		AdminPermissionsRequiredImpl(c)
	}
}

func AdminPermissionsRequiredImpl(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	userId := uint(claims[identityId].(float64))
	user, err := App.Store.LoadUserAsSelf(userId, userId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"User not found"})
		return
	}
	u := user.(*store.User)
	if !(u.Permissions >= store.UserPermissionsEditor) {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText":"User is not an editor"})
		return
	}
	c.Next();
}

func Exists(name string) bool {
	_, err := os.Stat(name)
	return !os.IsNotExist(err)
}

func addDefaultRouteToWebApp(router *gin.Engine) {
	router.NoRoute(func(c *gin.Context) {
		if Exists("./public/index.html") {
			c.File("./public/index.html")
		} else {
			c.File("../public/index.html")
		}
	})
}

func (a *WebApp) Run(addr string) {
	_ = a.Router.Run(addr);
}

func addWebAppStaticFiles(router *gin.Engine) {
	router.Static("/public", "./public")
	router.Use(static.Serve("/dist", static.LocalFile("./dist", true)))
}

func LoadUser(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	c.Header("Content-Type", "application/json")
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":"Invalid UserID"})
		return
	}
	if userId == 0 || uint(userId) == loggedInUserId {
		user, err := App.Store.LoadUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"User not found"})
			return
		}
		c.JSON(http.StatusOK, user)
	} else {
		user, err := App.Store.LoadPublicUser(uint(userId))
		if err != nil {
			c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"User not found"})
			return
		}
		c.JSON(http.StatusOK, user)
	}
}

func UpdateUser(c *gin.Context) {
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("UserID - err: %s", err.Error())})
		return
	}

	user, err := readJSONIntoUser(uint(userId), c)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("User details failed validation - err: %s", err.Error())})
		return
	}

	_, err = App.Store.UpdateUser(user)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "User updated successfully", "resourceId": userId,
		})
	}
}

func readJSONIntoUser(id uint, c *gin.Context) (*store.User, error) {
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	if id != loggedInUserId {
		err := errors.New("Only the logged in user can update their profile")
		return nil, err
	}
	user, err := App.Store.LoadUserAsSelf(uint(id), loggedInUserId)
	if err != nil {
		return nil, err
	}
	userJson := UserJSON{}
	err = c.BindJSON(&userJson)
	if err != nil {
		return nil, err
	}

	u := user.(*store.User)
	u.FirstName = userJson.FirstName
	u.MidNames = userJson.MidNames
	u.LastName = userJson.LastName
	u.Location = userJson.Location
	u.PhotoID = userJson.PhotoID
	u.Email = userJson.Email
	u.Mobile = userJson.Mobile

	return u, err
}

type UserJSON struct {
	FirstName string
	MidNames  string
	LastName  string
	Location  string
	PhotoID   uint
	Email     string
	Mobile    string
}

func ConceptsList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	concepts, err := App.Store.ListConcepts()
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":fmt.Sprintf("Concepts not found")})
	} else {
		c.JSON(http.StatusOK, concepts)
	}
}

func LoadConcept(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	conceptId, err := strconv.Atoi(c.Param("conceptID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":"Invalid ConceptID"})
		return
	}
	concept, err := App.Store.LoadConcept(uint(conceptId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"Concept not found"})
		return
	}
	conceptJSON := ConceptJSON{}
	conceptJSON.ID = concept.ID
	conceptJSON.Name = concept.Name
	conceptJSON.Summary = concept.Summary
	conceptJSON.Full = concept.Full
	c.JSON(http.StatusOK, conceptJSON)
}

func FetchConcept(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	tag := c.Param("tag")
	conceptTag, err := App.Store.FindConceptTag(tag)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"Concept Tag not found"})
		return
	}
	concept, err := App.Store.LoadConcept(conceptTag.ConceptId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"Concept for Tag not found"})
		return
	}
	conceptJSON := ConceptJSON{}
	conceptJSON.ID = concept.ID
	conceptJSON.Name = concept.Name
	conceptJSON.Summary = concept.Summary
	conceptJSON.Full = concept.Full
	c.JSON(http.StatusOK, conceptJSON)
}

func AddConcept(c *gin.Context) {
	concept := store.Concept{}

	err := readJSONIntoConcept(&concept, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("Concept failed validation - err: %s", err.Error())})
		return
	}

	conceptId, err := App.Store.InsertConcept(&concept)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":"Insert Concept failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Concept created successfully", "resourceId": conceptId,
	})
}

func UpdateConcept(c *gin.Context) {
	conceptId, err := strconv.Atoi(c.Param("conceptID"));
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("ConceptID invalid - err: %s", err.Error())})
		return
	}

	concept := &store.Concept{}
	concept, err = App.Store.LoadConcept(uint(conceptId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"Concept not found"})
		return
	}

	err = readJSONIntoConcept(concept, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("Concept details failed validation - err: %s", err.Error())})
		return
	}

	_, err = App.Store.UpdateConcept(concept)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "Concept updated successfully", "resourceId": conceptId,
		})
	}
}

func readJSONIntoConcept(concept *store.Concept, c *gin.Context, forceUpdate bool) (error) {
	conceptJSON := ConceptJSON{}
	err := c.BindJSON(&conceptJSON)
	if err != nil {
		return err
	}

	if forceUpdate || conceptJSON.ID == 0 {
		concept.ID = conceptJSON.ID
		concept.Name = conceptJSON.Name
		concept.Summary = conceptJSON.Summary
		concept.Full = conceptJSON.Full
	}
	return nil
}

type ConceptJSON struct {
	ID      uint
	Name    string
	Summary string
	Full    string
}

func ConceptTagsList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	tags, err := App.Store.ListConceptTags()
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"ConceptTags not found"})
	} else {
		c.JSON(http.StatusOK, tags)
	}
}

type ConceptTagJSON struct {
	ID        uint
	Tag       string
	ConceptId uint
}

func readJSONIntoConceptTag(conceptTag *store.ConceptTag, c *gin.Context, forceUpdate bool) (error) {
	conceptTagJSON := ConceptTagJSON{}
	err := c.BindJSON(&conceptTagJSON)
	if err != nil {
		return err
	}

	if forceUpdate || conceptTagJSON.ID == 0 {
		conceptTag.ID = conceptTagJSON.ID
		conceptTag.Tag = conceptTagJSON.Tag
		conceptTag.ConceptId = conceptTagJSON.ConceptId
	}
	return nil
}

func AddConceptTag(c *gin.Context) {
	conceptTag := store.ConceptTag{}

	err := readJSONIntoConceptTag(&conceptTag, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("Concept failed validation - err: %s", err.Error())})
		return
	}

	conceptTagId, err := App.Store.InsertConceptTag(&conceptTag)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("Insert Concept Tag failed - err: %s", err.Error())})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Concept Tag created successfully", "resourceId": conceptTagId,
	})
}

func DeleteConceptTag(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	id, err := strconv.Atoi(c.Param("conceptTagID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("Invalid ConceptTagID - err: %s", err.Error())})
		return
	}
	err = App.Store.DeleteConceptTag(uint(id))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":fmt.Sprintf("Delete ConceptTag Failed - err: %s", err.Error())})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "ConceptTag deleted", "resourceId": id,
		})
	}
}

func LoadConceptTags(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	conceptId, err := strconv.Atoi(c.Param("conceptID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText":"Invalid ConceptId"})
		return
	}
	conceptTags, err := App.Store.ConceptTagsForConceptId(uint(conceptId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText":"ConceptTags for Concept not found"})
		return
	}
	c.JSON(http.StatusOK, conceptTags)
}
