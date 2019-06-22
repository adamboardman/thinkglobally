package server

import (
	"errors"
	"fmt"
	"github.com/adamboardman/conceptualiser/store"
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

	a.JwtMiddleware = a.InitAuth(router)
	api.GET("/users/:userID", a.JwtMiddleware.MiddlewareFunc(), LoadUser)
	//api.GET("/users/:userID/photo", a.JwtMiddleware.MiddlewareFunc(), UserPhoto)
	//api.POST("/users/:userID/photo", a.JwtMiddleware.MiddlewareFunc(), AddUserPhoto)
	//api.PUT("/users/:userID/photo", a.JwtMiddleware.MiddlewareFunc(), UpdateUserPhoto)
	api.PUT("/users/:userID", a.JwtMiddleware.MiddlewareFunc(), UpdateUser)
	api.GET("/concepts", ConceptsList)
	api.GET("/concepts/:conceptID", LoadConcept)
	api.POST("/concepts", a.JwtMiddleware.MiddlewareFunc(), AddConcept)
	api.PUT("/concepts/:conceptID", a.JwtMiddleware.MiddlewareFunc(), UpdateConcept)
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
	a.Router.Run(addr);
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
		c.AbortWithStatus(http.StatusBadRequest)
	}
	if userId == 0 || uint(userId) == loggedInUserId {
		user, err := App.Store.LoadUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil {
			c.AbortWithStatus(http.StatusNotFound)
			return
		}
		c.JSON(http.StatusOK, user)
	} else {
		user, err := App.Store.LoadPublicUser(uint(userId))
		if err != nil {
			c.AbortWithStatus(http.StatusNotFound)
			return
		}
		c.JSON(http.StatusOK, user)
	}
}

func UpdateUser(c *gin.Context) {
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.String(http.StatusBadRequest, fmt.Sprintf("UserID - err: %s", err.Error()))
		return
	}

	user, err := readJSONIntoUser(uint(userId), c)
	if err != nil {
		c.String(http.StatusBadRequest, fmt.Sprintf("User details failed validation - err: %s", err.Error()))
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
		c.AbortWithStatus(http.StatusNotFound)
		return nil, err
	}
	userJson := UserJSON{}
	err = c.BindJSON(&userJson)
	if err != nil {
		c.AbortWithStatus(http.StatusBadRequest)
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
	FirstName        string
	MidNames         string
	LastName         string
	Location         string
	PhotoID          uint
	Email            string
	Mobile           string
}

func ConceptsList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	events, err := App.Store.ListConcepts()
	if err != nil {
		c.AbortWithStatus(http.StatusNotFound)
	} else {
		c.JSON(http.StatusOK, events)
	}
}

func LoadConcept(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	conceptId, err := strconv.Atoi(c.Param("conceptID"))
	if err != nil {
		c.AbortWithStatus(http.StatusBadRequest)
		return
	}
	event, err := App.Store.LoadConcept(uint(conceptId))
	if err != nil {
		c.AbortWithStatus(http.StatusNotFound)
		return
	}
	conceptJSON := ConceptJSON{}
	conceptJSON.ID = event.ID
	conceptJSON.Name = event.Name
	conceptJSON.Summary = event.Summary
	conceptJSON.Full = event.Full
	c.JSON(http.StatusOK, conceptJSON)
}

func AddConcept(c *gin.Context) {
	concept := store.Concept{}

	err := readJSONIntoConcept(&concept, c, true)
	if err != nil {
		c.String(http.StatusBadRequest, fmt.Sprintf("Concept failed validation - err: %s", err.Error()))
		return
	}

	conceptId, err := App.Store.InsertConcept(&concept)
	if err != nil {
		c.AbortWithStatus(http.StatusBadRequest)
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Event created successfully", "resourceId": conceptId,
	})
}

func UpdateConcept(c *gin.Context) {
	conceptId, err := strconv.Atoi(c.Param("conceptID"));
	if err != nil {
		c.String(http.StatusBadRequest, fmt.Sprintf("ConceptID invalid - err: %s", err.Error()))
		return
	}

	concept := &store.Concept{}
	concept, err = App.Store.LoadConcept(uint(conceptId))
	if err != nil {
		c.AbortWithStatus(http.StatusNotFound)
		return
	}

	err = readJSONIntoConcept(concept, c, true)
	if err != nil {
		c.String(http.StatusBadRequest, fmt.Sprintf("Concept details failed validation - err: %s", err.Error()))
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
