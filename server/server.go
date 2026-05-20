package server

import (
	"errors"
	"fmt"
	"math"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/adamboardman/thinkglobally/store"
	"github.com/adamboardman/thinkglobally/tag_updater"
	jwt "github.com/appleboy/gin-jwt/v3"
	"github.com/gin-gonic/contrib/static"
	"github.com/gin-gonic/gin"
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
	api.GET("/concepts", ConceptsList)
	api.GET("/concepts/:conceptID", LoadConcept)
	api.GET("/concepts/:conceptID/tags", LoadConceptTags)
	api.GET("/concept/:tag", FetchConcept)
	api.GET("/concept_tags", ConceptTagsList)
	api.Use(a.JwtMiddleware.MiddlewareFunc())
	{
		api.GET("/users/:userID", LoadUser)
		//api.GET("/users/:userID/photo",  UserPhoto)
		//api.POST("/users/:userID/photo", AddUserPhoto)
		//api.PUT("/users/:userID/photo",  UpdateUserPhoto)
		api.PUT("/users/:userID", UpdateUser)
		api.GET("/users", PublicUsersList)
		api.POST("/concepts", AdminPermissionsRequired(), AddConcept)
		api.PUT("/concepts/:conceptID", AdminPermissionsRequired(), UpdateConcept)
		api.POST("/concept_tags", AdminPermissionsRequired(), AddConceptTag)
		api.DELETE("/concept_tags/:conceptTagID", AdminPermissionsRequired(), DeleteConceptTag)
		api.DELETE("/concept_tags", AdminPermissionsRequired(), DeleteConceptTags)
		api.POST("/transactions", AddTransaction)
		api.PATCH("/transactions/:transactionID/accept", AcceptTransaction)
		api.PATCH("/transactions/:transactionID/reject", RejectTransaction)
		api.GET("/transactions", TransactionsList)
		api.GET("/living_wage_locations", LivingWageLocationsList)
		api.POST("/living_wage_locations", AdminPermissionsRequired(), AddLivingWageLocation)
		api.PUT("/living_wage_locations/:locationID", AdminPermissionsRequired(), UpdateLivingWageLocation)
		api.GET("/living_wage_locations/:locationID", LoadLivingWageLocation)
		api.GET("/living_wages/for_location/:locationID", LivingWagesList)
		api.GET("/living_wages", LivingWagesList)
		api.POST("/living_wages", AdminPermissionsRequired(), AddLivingWage)
		api.PUT("/living_wages/:livingWageID", AdminPermissionsRequired(), UpdateLivingWage)
		api.GET("/living_wages/:livingWageID", LoadLivingWage)
	}
}

func AdminPermissionsRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		AdminPermissionsRequiredImpl(c)
	}
}

func AdminPermissionsRequiredImpl(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	userId := uint(claims[identityId].(float64))
	user, err := App.Store.LoadPrivilegedUserAsSelf(userId, userId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "User not found"})
		return
	}
	if !(user.Permissions >= store.UserPermissionsEditor) {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "User is not an editor"})
		return
	}
	c.Next()
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
	_ = a.Router.Run(addr)
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
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid UserID"})
		return
	}
	if userId == 0 || uint(userId) == loggedInUserId {
		user, err := App.Store.LoadPrivilegedUserAsSelf(loggedInUserId, loggedInUserId)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "User not found"})
			return
		}
		transaction, err := App.Store.LastConfirmedTransactionForUser(loggedInUserId)
		var balance int64 = 0
		if err == nil {
			if transaction.FromUserId == loggedInUserId {
				balance = transaction.FromUserBalance
			} else {
				balance = transaction.ToUserBalance
			}
		}
		//transactions, err := App.Store.ListTransactionsForUser(loggedInUserId)

		userWithBalance := store.PrivilegedUserWithBalance{
			PrivilegedUser: *user,
			Balance:        balance,
		}
		c.JSON(http.StatusOK, userWithBalance)
	} else {
		user, err := App.Store.LoadPublicUser(uint(userId))
		if err != nil {
			c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "User not found"})
			return
		}
		//TODO check that we have interacted with this user in the past otherwise throw an error?
		c.JSON(http.StatusOK, user)
	}
}

func UpdateUser(c *gin.Context) {
	userId, err := strconv.Atoi(c.Param("userID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("UserID - err: %s", err.Error())})
		return
	}

	user, err := readJSONIntoUser(uint(userId), c)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("User details failed validation - err: %s", err.Error())})
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

	user.FirstName = userJson.FirstName
	user.MidNames = userJson.MidNames
	user.LastName = userJson.LastName
	user.Location = userJson.Location
	user.LocationId = userJson.LocationId
	user.PhotoId = userJson.PhotoId
	user.Email = userJson.Email
	user.Mobile = userJson.Mobile

	return user, err
}

type UserJSON struct {
	FirstName  string
	MidNames   string
	LastName   string
	Location   string
	LocationId uint
	PhotoId    uint
	Email      string
	Mobile     string
}

func ConceptsList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	concepts, err := App.Store.ListConcepts()
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": fmt.Sprintf("Concepts not found")})
	} else {
		c.JSON(http.StatusOK, concepts)
	}
}

func LoadConcept(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	conceptId, err := strconv.Atoi(c.Param("conceptID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid ConceptID"})
		return
	}
	concept, err := App.Store.LoadConcept(uint(conceptId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Concept not found"})
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
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Concept Tag not found"})
		return
	}
	concept, err := App.Store.LoadConcept(conceptTag.ConceptId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Concept for Tag not found"})
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
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Concept failed validation - err: %s", err.Error())})
		return
	}

	conceptTags, _ := App.Store.ListConceptTags()
	concepts, _ := App.Store.ListConcepts()
	concept.Full = tag_updater.UpdateTags(conceptTags, concepts, concept.Full, concept.ID)

	conceptId, err := App.Store.InsertConcept(&concept)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Insert Concept failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Concept created successfully", "resourceId": conceptId,
	})
}

func UpdateConcept(c *gin.Context) {
	conceptId, err := strconv.Atoi(c.Param("conceptID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("ConceptID invalid - err: %s", err.Error())})
		return
	}

	concept := &store.Concept{}
	concept, err = App.Store.LoadConcept(uint(conceptId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Concept not found"})
		return
	}

	err = readJSONIntoConcept(concept, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Concept details failed validation - err: %s", err.Error())})
		return
	}

	conceptTags, _ := App.Store.ListConceptTags()
	concepts, _ := App.Store.ListConcepts()
	concept.Full = tag_updater.UpdateTags(conceptTags, concepts, concept.Full, concept.ID)

	_, err = App.Store.UpdateConcept(concept)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "Concept updated successfully", "resourceId": conceptId,
		})
	}
}

func readJSONIntoConcept(concept *store.Concept, c *gin.Context, forceUpdate bool) error {
	conceptJSON := ConceptJSON{}
	err := c.ShouldBindJSON(&conceptJSON)
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
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "ConceptTags not found"})
	} else {
		c.JSON(http.StatusOK, tags)
	}
}

type ConceptTagJSON struct {
	ID        uint
	Tag       string
	ConceptId uint
}

func readJSONIntoConceptTag(conceptTag *store.ConceptTag, c *gin.Context, forceUpdate bool) error {
	conceptTagJSON := ConceptTagJSON{}
	err := c.ShouldBindJSON(&conceptTagJSON)
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
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Concept failed validation - err: %s", err.Error())})
		return
	}

	conceptTagId, err := App.Store.InsertConceptTag(&conceptTag)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Insert Concept Tag failed - err: %s", err.Error())})
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
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Invalid ConceptTagID - err: %s", err.Error())})
		return
	}
	err = App.Store.DeleteConceptTag(uint(id))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Delete ConceptTag Failed - err: %s", err.Error())})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "ConceptTag deleted", "resourceId": id,
		})
	}
}

type ConceptTagIDs []uint

func DeleteConceptTags(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	conceptTagIDs := ConceptTagIDs{}
	err := c.BindJSON(&conceptTagIDs)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Invalid ConceptTagIDs - err: %s", err.Error())})
		return
	}
	for _, id := range conceptTagIDs {
		err = App.Store.DeleteConceptTag(uint(id))
	}
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Delete ConceptTag Failed - err: %s", err.Error())})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "ConceptTag deleted", "resourceIds": conceptTagIDs,
		})
	}
}

func LoadConceptTags(c *gin.Context) {
	c.Header("Content-Type", "application/json")

	conceptId, err := strconv.Atoi(c.Param("conceptID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid ConceptId"})
		return
	}
	conceptTags, err := App.Store.ConceptTagsForConceptId(uint(conceptId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "ConceptTags for Concept not found"})
		return
	}
	c.JSON(http.StatusOK, conceptTags)
}

type TransactionJSON struct {
	ID              uint
	FromUserId      uint
	ToUserId        uint
	InitiatedDate   store.PosixDateTime
	ConfirmedDate   store.PosixDateTime
	Email           string
	Seconds         uint64
	Multiplier      float32
	TxFee           uint
	Description     string
	Location        string
	LocationId      uint
	ToPreviousTId   uint
	FromPreviousTId uint
	Status          uint
}

func readJSONIntoTransaction(transaction *store.Transaction, c *gin.Context, forceUpdate bool) error {
	transactionJSON := TransactionJSON{}
	err := c.BindJSON(&transactionJSON)
	if err != nil {
		return err
	}

	if forceUpdate || transactionJSON.ID == 0 {
		transaction.ID = transactionJSON.ID
		transaction.FromUserId = transactionJSON.FromUserId
		transaction.ToUserId = transactionJSON.ToUserId
		transaction.InitiatedDate = transactionJSON.InitiatedDate
		transaction.ConfirmedDate = transactionJSON.ConfirmedDate
		transaction.Seconds = transactionJSON.Seconds
		transaction.Multiplier = transactionJSON.Multiplier
		transaction.TxFee = transactionJSON.TxFee
		transaction.Description = transactionJSON.Description
		transaction.Location = transactionJSON.Location
		transaction.LocationId = transactionJSON.LocationId
		transaction.ToPreviousTId = transactionJSON.ToPreviousTId
		transaction.FromPreviousTId = transactionJSON.FromPreviousTId
		transaction.Status = transactionJSON.Status
	}

	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	switch transaction.Status {
	case store.TransactionOffered:
		if transaction.FromUserId != loggedInUserId {
			return errors.New("you can only offer transactions from yourself")
		}
	case store.TransactionRequested:
		if transaction.ToUserId != loggedInUserId {
			return errors.New("you can only request transactions to yourself")
		}
	}
	if transaction.FromUserId == transaction.ToUserId {
		return errors.New("you can not create transactions from and to yourself")
	}
	txFee := uint(math.Floor(0.0002 * float64(transaction.Seconds)))
	if transaction.TxFee < 1 || transaction.TxFee < txFee {
		return errors.New("you must pay a 0.02% or greater transaction fee")
	}

	switch transaction.Status {
	case store.TransactionOffered:
		if transaction.ToUserId == 0 {
			transaction.ToUserId = FindOrAddUserForTransaction(transactionJSON, loggedInUserId)
		}
		break
	case store.TransactionRequested:
		if transaction.FromUserId == 0 {
			transaction.FromUserId = FindOrAddUserForTransaction(transactionJSON, loggedInUserId)
		}
		break
	}

	if transaction.FromUserId == transaction.ToUserId {
		return errors.New("you can not create transactions from and to yourself")
	}

	return nil
}

func FindOrAddUserForTransaction(transactionJSON TransactionJSON, loggedInUserId uint) uint {
	user, err := App.Store.FindUser(transactionJSON.Email)
	self, err2 := App.Store.LoadPublicUser(loggedInUserId)
	if err != nil && err2 == nil {
		invite := self.FirstName + " " + self.LastName
		if transactionJSON.Status == store.TransactionOffered {
			invite += " offered "
		} else {
			invite += " requested "
		}
		invite += "the following transaction "
		invite += fmt.Sprintf("%g", float64(transactionJSON.Seconds)/3600.0)
		invite += "TGs"
		err, user = InviteUser(transactionJSON.Email, invite, transactionJSON.Description)
		if err != nil {
			return 0
		}
	}
	return user.ID
}

func AddTransaction(c *gin.Context) {
	transaction := store.Transaction{}

	err := readJSONIntoTransaction(&transaction, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Transaction failed validation - error: %s", err.Error())})
		return
	}

	transactionId, err := App.Store.InsertTransaction(&transaction)
	if err != nil || transactionId == 0 {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Insert Transaction failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "Transaction created successfully", "resourceId": transactionId,
	})
}

func AcceptTransaction(c *gin.Context) {
	c.Header("Content-Type", "application/json")

	transactionId, err := strconv.Atoi(c.Param("transactionID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid TransactionId"})
		return
	}
	transaction, err := App.Store.LoadTransaction(uint(transactionId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Transaction not found"})
		return
	}
	if transaction.Status != store.TransactionOffered && transaction.Status != store.TransactionRequested {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Transaction not offered or requested"})
		return
	}

	fromUserLastTransaction, _ := App.Store.LastConfirmedTransactionForUser(transaction.FromUserId)
	toUserLastTransaction, _ := App.Store.LastConfirmedTransactionForUser(transaction.ToUserId)

	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))
	if transaction.Status == store.TransactionOffered {
		if transaction.ToUserId != loggedInUserId {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "You can only accept offer transactions offered to yourself"})
			return
		}

		transaction.Status = store.TransactionOfferApproved
		transaction.FromUserBalance = fromUserLastTransaction.Balance(transaction.FromUserId) - (int64(transaction.Seconds) + int64(transaction.TxFee))
		transaction.ToUserBalance = toUserLastTransaction.Balance(transaction.ToUserId) + int64(transaction.Seconds)
	}
	if transaction.Status == store.TransactionRequested {
		if transaction.FromUserId != loggedInUserId {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "You can only accept request transactions requested from yourself"})
			return
		}

		transaction.Status = store.TransactionRequestApproved
		transaction.FromUserBalance = fromUserLastTransaction.Balance(transaction.FromUserId) - int64(transaction.Seconds)
		transaction.ToUserBalance = toUserLastTransaction.Balance(transaction.ToUserId) + (int64(transaction.Seconds) - int64(transaction.TxFee))
	}
	transaction.ConfirmedDate = store.PosixDateTime(time.Now().UTC())
	_, err = App.Store.UpdateTransaction(transaction)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Transaction failed update - err: %s", err.Error())})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusAccepted, "message": "Transaction updated successfully", "resourceId": transactionId,
	})
}

func RejectTransaction(c *gin.Context) {
	c.Header("Content-Type", "application/json")

	transactionId, err := strconv.Atoi(c.Param("transactionID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid TransactionId"})
		return
	}
	transaction, err := App.Store.LoadTransaction(uint(transactionId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Transaction not found"})
		return
	}
	if transaction.Status != store.TransactionOffered && transaction.Status != store.TransactionRequested {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Transaction not offered or requested"})
		return
	}

	fromUserLastTransaction, _ := App.Store.LastConfirmedTransactionForUser(transaction.FromUserId)
	toUserLastTransaction, _ := App.Store.LastConfirmedTransactionForUser(transaction.ToUserId)

	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))
	if transaction.Status == store.TransactionOffered {
		if transaction.ToUserId != loggedInUserId {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "You can only reject transactions offered to yourself"})
			return
		}

		transaction.Status = store.TransactionOfferRejected
		transaction.FromUserBalance = fromUserLastTransaction.Balance(transaction.FromUserId)
		transaction.ToUserBalance = toUserLastTransaction.Balance(transaction.ToUserId)
	}
	if transaction.Status == store.TransactionRequested {
		if transaction.FromUserId != loggedInUserId {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"statusText": "You can only reject transactions requested from yourself"})
			return
		}

		transaction.Status = store.TransactionRequestRejected
		transaction.FromUserBalance = fromUserLastTransaction.Balance(transaction.FromUserId)
		transaction.ToUserBalance = toUserLastTransaction.Balance(transaction.ToUserId)
	}
	transaction.ConfirmedDate = store.PosixDateTime(time.Now().UTC())
	_, err = App.Store.UpdateTransaction(transaction)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Transaction failed update - err: %s", err.Error())})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusAccepted, "message": "Transaction updated successfully", "resourceId": transactionId,
	})
}

func TransactionsList(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	c.Header("Content-Type", "application/json")
	transactions, err := App.Store.ListTransactionsForUser(loggedInUserId)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Transactions not found"})
	} else {
		c.JSON(http.StatusOK, transactions)
	}
}

func PublicUsersList(c *gin.Context) {
	claims := jwt.ExtractClaims(c)
	loggedInUserId := uint(claims["id"].(float64))

	c.Header("Content-Type", "application/json")
	type EmailQuery struct {
		Email string
	}
	var userQuery EmailQuery
	err := c.ShouldBindQuery(&userQuery)
	if err == nil && len(userQuery.Email) > 0 {
		user, err := App.Store.FindUser(userQuery.Email)
		if err == nil {
			if user.ID > 0 {
				publicUser, err := App.Store.LoadPublicUser(uint(user.ID))
				if err == nil {
					publicUserWithBalance := publicUserWithBalanceFromUser(publicUser)
					c.JSON(http.StatusOK, publicUserWithBalance)
					return
				}
			}
		}
	} else {
		users, err := App.Store.ListTransactionPartners(loggedInUserId)
		var publicUsersWithBalance []store.PublicUserWithBalance
		for _, user := range users {
			publicUsersWithBalance = append(publicUsersWithBalance, publicUserWithBalanceFromUser(&user))
		}
		if err == nil {
			c.JSON(http.StatusOK, publicUsersWithBalance)
			return
		}
	}
	c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Invalid users search"})
}

func publicUserWithBalanceFromUser(publicUser *store.PublicUser) store.PublicUserWithBalance {
	transaction, err := App.Store.LastConfirmedTransactionForUser(publicUser.ID)
	var balance int64 = 0
	if err == nil {
		if transaction.FromUserId == publicUser.ID {
			balance = transaction.FromUserBalance
		} else {
			balance = transaction.ToUserBalance
		}
	}
	publicUserWithBalance := store.PublicUserWithBalance{
		PublicUser: *publicUser,
		Balance:    balance,
	}
	return publicUserWithBalance
}

type LivingWageLocationJSON struct {
	ID     uint
	Name   string
	Symbol string
}

func readJSONIntoLivingWageLocation(livingWageLocation *store.LivingWageLocation, c *gin.Context, forceUpdate bool) error {
	livingWageLocationJSON := LivingWageLocationJSON{}
	err := c.BindJSON(&livingWageLocationJSON)
	if err != nil {
		return err
	}

	if forceUpdate || livingWageLocationJSON.ID == 0 {
		livingWageLocation.ID = livingWageLocationJSON.ID
		livingWageLocation.Name = livingWageLocationJSON.Name
		livingWageLocation.Symbol = livingWageLocationJSON.Symbol
	}

	return nil
}

func AddLivingWageLocation(c *gin.Context) {
	livingWageLocation := store.LivingWageLocation{}

	err := readJSONIntoLivingWageLocation(&livingWageLocation, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("LivingWageLocation failed validation - error: %s", err.Error())})
		return
	}

	livingWageLocationId, err := App.Store.InsertLivingWageLocation(&livingWageLocation)
	if err != nil || livingWageLocationId == 0 {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Insert LivingWageLocation failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "LivingWageLocation created successfully", "resourceId": livingWageLocationId,
	})
}

type LivingWageJSON struct {
	ID         uint
	StartDate  store.PosixDateTime
	StopDate   store.PosixDateTime
	Wage       float32
	LocationId uint
}

func readJSONIntoLivingWage(livingWage *store.LivingWage, c *gin.Context, forceUpdate bool) error {
	livingWageJSON := LivingWageJSON{}
	err := c.BindJSON(&livingWageJSON)
	if err != nil {
		return err
	}

	if forceUpdate || livingWageJSON.ID == 0 {
		livingWage.ID = livingWageJSON.ID
		livingWage.StartDate = livingWageJSON.StartDate
		livingWage.StopDate = livingWageJSON.StopDate
		livingWage.Wage = livingWageJSON.Wage
		livingWage.LocationId = livingWageJSON.LocationId
	}

	return nil
}

func LivingWageLocationsList(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	livingWageLocations, err := App.Store.ListLivingWageLocations()
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Living Wage Locations not found"})
	} else {
		c.JSON(http.StatusOK, livingWageLocations)
	}
}

func LoadLivingWageLocation(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	livingWageLocationId, err := strconv.Atoi(c.Param("locationID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid LocationID"})
		return
	}
	livingWageLocation, err := App.Store.LoadLivingWageLocation(uint(livingWageLocationId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Living Wage Location not found"})
		return
	}
	livingWageLocationJSON := LivingWageLocationJSON{}
	livingWageLocationJSON.ID = livingWageLocation.ID
	livingWageLocationJSON.Name = livingWageLocation.Name
	livingWageLocationJSON.Symbol = livingWageLocation.Symbol
	c.JSON(http.StatusOK, livingWageLocationJSON)
}

func LivingWagesList(c *gin.Context) {
	c.Header("Content-Type", "application/json")

	var livingWages []store.LivingWage

	locationId, err := strconv.Atoi(c.Param("locationID"))
	if err == nil {
		livingWages, err = App.Store.ListLivingWagesForLocation(uint(locationId))
	} else {
		livingWages, err = App.Store.ListLivingWages()
	}
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Living Wages not found"})
	} else {
		c.JSON(http.StatusOK, livingWages)
	}
}

func AddLivingWage(c *gin.Context) {
	livingWage := store.LivingWage{}

	err := readJSONIntoLivingWage(&livingWage, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("LivingWage failed validation - error: %s", err.Error())})
		return
	}

	livingWageId, err := App.Store.InsertLivingWage(&livingWage)
	if err != nil || livingWageId == 0 {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Insert LivingWage failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"status": http.StatusCreated, "message": "LivingWage created successfully", "resourceId": livingWageId,
	})
}

func LoadLivingWage(c *gin.Context) {
	c.Header("Content-Type", "application/json")
	livingWageId, err := strconv.Atoi(c.Param("livingWageID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": "Invalid LivingWageID"})
		return
	}
	livingWage, err := App.Store.LoadLivingWage(uint(livingWageId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Living Wage not found"})
		return
	}
	livingWageJSON := LivingWageJSON{}
	livingWageJSON.ID = livingWage.ID
	livingWageJSON.StartDate = livingWage.StartDate
	livingWageJSON.StopDate = livingWage.StopDate
	livingWageJSON.LocationId = livingWage.LocationId
	livingWageJSON.Wage = livingWage.Wage
	c.JSON(http.StatusOK, livingWageJSON)
}

func UpdateLivingWage(c *gin.Context) {
	livingWageId, err := strconv.Atoi(c.Param("livingWageID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("LivingWageID invalid - err: %s", err.Error())})
		return
	}

	livingWage := &store.LivingWage{}
	livingWage, err = App.Store.LoadLivingWage(uint(livingWageId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Living Wage not found"})
		return
	}

	err = readJSONIntoLivingWage(livingWage, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Living Wage details failed validation - err: %s", err.Error())})
		return
	}

	_, err = App.Store.UpdateLivingWage(livingWage)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "Living Wage updated successfully", "resourceId": livingWageId,
		})
	}
}

func UpdateLivingWageLocation(c *gin.Context) {
	livingWageLocationId, err := strconv.Atoi(c.Param("locationID"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("LocationID invalid - err: %s", err.Error())})
		return
	}

	livingWageLocation := &store.LivingWageLocation{}
	livingWageLocation, err = App.Store.LoadLivingWageLocation(uint(livingWageLocationId))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"statusText": "Living Wage Location not found"})
		return
	}

	err = readJSONIntoLivingWageLocation(livingWageLocation, c, true)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"statusText": fmt.Sprintf("Living Wage Location details failed validation - err: %s", err.Error())})
		return
	}

	_, err = App.Store.UpdateLivingWageLocation(livingWageLocation)
	if err == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": http.StatusOK, "message": "Living Wage Location updated successfully", "resourceId": livingWageLocationId,
		})
	}
}
