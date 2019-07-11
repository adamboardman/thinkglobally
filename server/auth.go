package server

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"github.com/adamboardman/thinkglobally/store"
	"github.com/appleboy/gin-jwt"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/argon2"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/smtp"
	"net/url"
	"time"
)

type login struct {
	Email    string `form:"email" json:"email" binding:"required"`
	Password string `form:"password" json:"password" binding:"required"`
}

var identityId = "id"
var identityKey = "email"
var identityConfirmed = "confirmed"

type LoggedInUser struct {
	ID        uint
	Email     string
	Confirmed bool
}

func LogFatalError(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func RandomKey(len int) string {
	key := RandomBytes(len)
	return base64.StdEncoding.EncodeToString(key)
}

func RandomBytes(len int) []byte {
	key := make([]byte, len)
	_, err := io.ReadFull(rand.Reader, key)
	LogFatalError(err)
	return key
}

func (a *WebApp) InitAuth(r *gin.Engine) *jwt.GinJWTMiddleware {
	const secretKeyFileName = "secret_key.txt"
	secretKey, err := ioutil.ReadFile(secretKeyFileName)
	if err != nil {
		secretKey, err = ioutil.ReadFile("../" + secretKeyFileName)
		if err != nil {
			secretKey = []byte(RandomKey(30))
			err = ioutil.WriteFile(secretKeyFileName, secretKey, 0666)
			LogFatalError(err)
		}
	}

	authMiddleware, err := jwt.New(&jwt.GinJWTMiddleware{
		Realm:       "test zone",
		Key:         secretKey,
		Timeout:     time.Hour * 24 * 7,
		MaxRefresh:  time.Hour,
		IdentityKey: identityKey,
		PayloadFunc: func(data interface{}) jwt.MapClaims {
			if v, ok := data.(*store.User); ok {
				return jwt.MapClaims{
					identityId:        v.ID,
					identityKey:       v.Email,
					identityConfirmed: v.Confirmed,
				}
			}
			return jwt.MapClaims{}
		},
		IdentityHandler: func(c *gin.Context) interface{} {
			claims := jwt.ExtractClaims(c)
			return &LoggedInUser{
				ID:        uint(claims[identityId].(float64)),
				Email:     claims[identityKey].(string),
				Confirmed: claims[identityConfirmed] == true,
			}
		},
		Authenticator: func(c *gin.Context) (interface{}, error) {
			var loginVals login
			if err := c.ShouldBind(&loginVals); err != nil {
				return "", jwt.ErrMissingLoginValues
			}

			user, err := a.Store.FindUser(loginVals.Email)
			salt, _ := base64.StdEncoding.DecodeString(user.Salt)
			encrypted := argon2.IDKey([]byte(loginVals.Password), salt, 1, 64*1024, 4, 32)
			loginPassword := base64.StdEncoding.EncodeToString(encrypted)
			if err == nil && loginPassword == user.Password {
				return user, nil
			}

			return nil, jwt.ErrFailedAuthentication
		},
		Authorizator: func(data interface{}, c *gin.Context) bool {
			user, ok := data.(*LoggedInUser);
			if ok && user.Confirmed {
				return true
			}

			return false
		},
		Unauthorized: func(c *gin.Context, code int, message string) {
			c.JSON(code, gin.H{
				"code":    code,
				"message": message,
			})
		},

		TokenLookup: "header: Authorization",

		TokenHeadName: "Bearer",

		TimeFunc: time.Now,
	})

	if err != nil {
		log.Fatal("JWT Error:" + err.Error())
	}

	auth := r.Group("/auth")
	auth.POST("/register", RegisterUser)
	auth.POST("/login", authMiddleware.LoginHandler)
	auth.GET("/confirm_email", ConfirmEmail)
	auth.GET("/refresh_token", authMiddleware.MiddlewareFunc(), authMiddleware.RefreshHandler)

	return authMiddleware
}

type RegisterJSON struct {
	Email                string
	Password             string
	PasswordConfirmation string
}

func RegisterUser(c *gin.Context) {
	registerJSON := RegisterJSON{}
	if c.ContentType() == "application/json" {
		err := c.BindJSON(&registerJSON)
		if err != nil {
			c.AbortWithStatus(http.StatusBadRequest)
			return
		}
	} else {
		registerJSON.Email = c.PostForm("email")
		registerJSON.Password = c.PostForm("password")
		registerJSON.PasswordConfirmation = c.PostForm("password_confirmation")
	}

	if registerJSON.Password != registerJSON.PasswordConfirmation {
		c.AbortWithStatus(http.StatusBadRequest)
		return
	}

	existingUser, _ := App.Store.FindUser(registerJSON.Email)
	if existingUser != nil {
		c.AbortWithStatus(http.StatusBadRequest)
		return
	}

	user := store.User{}
	user.Email = registerJSON.Email
	salt := RandomBytes(16)
	encrypted := argon2.IDKey([]byte(registerJSON.Password), salt, 1, 64*1024, 4, 32)
	user.Salt = base64.StdEncoding.EncodeToString(salt)
	user.Password = base64.StdEncoding.EncodeToString(encrypted)

	verification := RandomBytes(20)
	verificationKey := argon2.IDKey(verification, salt, 1, 64*1024, 4, 32)
	user.ConfirmVerifier = base64.StdEncoding.EncodeToString(verificationKey)

	_, err := App.Store.InsertUser(&user)
	if err != nil {
		c.AbortWithStatus(http.StatusBadRequest)
		return
	}

	SendEmail(registerJSON.Email, base64.StdEncoding.EncodeToString(verification))

	c.JSON(http.StatusOK, gin.H{
		"status": http.StatusOK, "message": "User registered successfully", "resourceId": user.ID,
	})
}

func SendEmail(emailAddress string, verificationKey string) {
	data := url.Values{}
	data.Set("email", emailAddress)
	data.Set("verification", verificationKey)
	confirmUrl := "https://www.thinkglobally.org/auth/confirm_email?" + data.Encode()
	log.Print(confirmUrl)
	c, err := smtp.Dial("localhost:25")
	if err != nil {
		log.Print(err)
		return
	}
	defer c.Close()
	_ = c.Mail("no-reply@thinkglobally.org")
	_ = c.Rcpt(emailAddress)
	wc, err := c.Data()
	LogFatalError(err)
	defer wc.Close()
	buf := bytes.NewBufferString("" +
		"Subject: Thinkglobally Confirm Email Address\r\n" +
		"\r\n" +
		"Please click on the following link to confirm your account " + confirmUrl)
	_, err = buf.WriteTo(wc)
	LogFatalError(err)
}

func ConfirmEmail(c *gin.Context) {
	email := c.Query("email")
	verificationKey := c.Query("verification")

	log.Print(email + verificationKey)

	user, err := App.Store.FindUser(email)
	salt, _ := base64.StdEncoding.DecodeString(user.Salt)
	verification, _ := base64.StdEncoding.DecodeString(verificationKey)
	encrypted := argon2.IDKey(verification, salt, 1, 64*1024, 4, 32)
	confirmVerification := base64.StdEncoding.EncodeToString(encrypted)
	if err == nil && confirmVerification == user.ConfirmVerifier {
		user.Confirmed = true
		user.ConfirmVerifier = ""
		_, _ = App.Store.UpdateUser(user)
		c.Redirect(307, "/")
	} else {
		c.AbortWithStatus(http.StatusBadRequest)
	}
}
