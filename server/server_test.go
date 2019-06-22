package server

import (
	"bytes"
	"encoding/json"
	"github.com/adamboardman/conceptualiser/store"
	. "github.com/smartystreets/goconvey/convey"
	"golang.org/x/crypto/bcrypt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
)

type Response struct {
	Token string `json:"token"`
}

var a WebApp

func TestMain(m *testing.M) {
	a = WebApp{}
	a.Init("test-db")

	code := m.Run()

	os.Exit(code)
}

func TestWebApp404(t *testing.T) {
	Convey("Open an invalid URL", t, func() {
		req, _ := http.NewRequest("GET", "/invalidurl", nil)
		response := httptest.NewRecorder()
		a.Router.ServeHTTP(response, req)

		Convey("The server should respond with StatusOK (defaults to react web app)", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})
	})
}

func TestWebAppIndex(t *testing.T) {
	Convey("Web Index", t, func() {
		req, _ := http.NewRequest("GET", "/", nil)
		response := httptest.NewRecorder()
		a.Router.ServeHTTP(response, req)

		Convey("The server should respond with StatusOK", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})
	})
}

func TestRegisterUser(t *testing.T) {
	Convey("Given test user is not in database", t, func() {
		const emailAddress = "test@example.com"
		a.Store.PurgeUser(emailAddress)

		Convey("The user registers", func() {
			registerJSON := RegisterJSON{}
			registerJSON.Email = emailAddress;
			registerJSON.Password = "1234";
			registerJSON.PasswordConfirmation = "1234";
			data, _ := json.Marshal(registerJSON)
			postData := bytes.NewReader(data)
			req, _ := http.NewRequest("POST", "/auth/register", postData)
			req.Header.Set("Content-Type", "application/json")
			response := httptest.NewRecorder()
			a.Router.ServeHTTP(response, req)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			Convey("Should send an email with verification code", func() {
				savedUser, _ := a.Store.FindUser(emailAddress)
				So(savedUser.ConfirmVerifier, ShouldNotBeNil)
			})
		})
	})
}

func TestInvalidTokenRejection(t *testing.T) {
	Convey("Refreshing an invalid token", t, func() {
		token := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6InRlc3Q3QGV4YW1wbGUuY29tIiwiZXhwIjoxNTM2Njc3NzUxLCJvcmlnX2lhdCI6MTUzNjY3NDE1MX0.65PStZIR8yRhJo7w2cF8VL-dtF1CbrOnvdB6ub9GxdY"
		req, _ := http.NewRequest("GET", "/auth/refresh_token", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		response := httptest.NewRecorder()
		a.Router.ServeHTTP(response, req)
		Convey("Should give an error", func() {
			So(response.Code, ShouldEqual, http.StatusUnauthorized)
		})
	})
}

func TestConfirmEmail(t *testing.T) {
	Convey("Given test user without confirmation is in database", t, func() {
		const emailAddress = "test-confirmed@example.com"
		const verificationKey = "5678"
		a.Store.PurgeUser(emailAddress)

		encrypted, _ := bcrypt.GenerateFromPassword([]byte(verificationKey), 13)
		user := store.User{
			Email:           emailAddress,
			ConfirmVerifier: string(encrypted),
		}
		a.Store.InsertUser(&user)

		Convey("The user confirms email address and is redirected to the web app", func() {
			data := url.Values{}
			data.Set("email", emailAddress)
			data.Set("verification", verificationKey)
			req, _ := http.NewRequest("GET", "/auth/confirm_email?"+data.Encode(), nil)
			req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
			response := httptest.NewRecorder()
			a.Router.ServeHTTP(response, req)
			So(response.Code, ShouldEqual, http.StatusTemporaryRedirect)
		})
	})
}

func TestMinimalSiteAccessWithoutConfirmedEmail(t *testing.T) {
	Convey("Given unconfirmed test user", t, func() {
		const emailAddress = "test-unconfirmed@example.com"
		user := ensureTestUserExists(emailAddress)
		user.Confirmed = false
		a.Store.UpdateUser(user)

		response := loginToUser(emailAddress)

		Convey("Login should succeed", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})

		token := userTokenFromLoginResponse(response)

		Convey("Attempt to add a concept", func() {
			req, _ := http.NewRequest("POST", "/api/concepts", nil)
			req.Header.Set("Authorization", "Bearer "+token)
			response2 := httptest.NewRecorder()
			a.Router.ServeHTTP(response2, req)

			Convey("Should return error", func() {
				So(response2.Code, ShouldEqual, http.StatusForbidden);
			})
		})
	})
}

func TestRefreshToken(t *testing.T) {
	Convey("Given confirmed test user", t, func() {
		const emailAddress = "test@example.com"
		user := ensureTestUserExists(emailAddress)
		user.Confirmed = true
		a.Store.UpdateUser(user)

		response := loginToUser(emailAddress)

		Convey("Login should succeed", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})

		token := userTokenFromLoginResponse(response)

		Convey("Should be able to refresh a token", func() {
			req2, _ := http.NewRequest("GET", "/auth/refresh_token", nil)
			req2.Header.Set("Authorization", "Bearer "+token)
			response2 := httptest.NewRecorder()
			a.Router.ServeHTTP(response2, req2)
			So(response2.Code, ShouldEqual, http.StatusOK)
		})
	})
}

func userTokenFromLoginResponse(response *httptest.ResponseRecorder) string {
	body, err := ioutil.ReadAll(response.Body)
	responseData := new(Response)
	err = json.Unmarshal(body, responseData)
	So(err, ShouldBeNil)
	token := responseData.Token
	return token
}

func loginToUser(emailAddress string) *httptest.ResponseRecorder {
	data := url.Values{}
	data.Set("email", emailAddress)
	data.Set("password", "1234")
	postData := strings.NewReader(data.Encode())
	req, _ := http.NewRequest("POST", "/auth/login", postData)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	response := httptest.NewRecorder()
	a.Router.ServeHTTP(response, req)
	return response
}

type LoginJSON struct {
	Email    string
	Password string
}

func loginToUserJSON(emailAddress string) *httptest.ResponseRecorder {
	loginJSON := LoginJSON{}
	loginJSON.Email = emailAddress
	loginJSON.Password = "1234"
	data, _ := json.Marshal(loginJSON)
	post_data := bytes.NewReader(data)
	req, _ := http.NewRequest("POST", "/auth/login", post_data)
	req.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	a.Router.ServeHTTP(response, req)
	return response
}

func ensureTestUserExists(emailAddress string) *store.User {
	user, err := a.Store.FindUser(emailAddress)
	if err != nil {
		encrypted, err := bcrypt.GenerateFromPassword([]byte("1234"), 13)
		So(err, ShouldBeNil)
		user = &store.User{
			Email:     emailAddress,
			Password:  string(encrypted),
			Confirmed: true,
		}
		_, _ = a.Store.InsertUser(user)
	}
	return user
}

func TestConceptsList(t *testing.T) {
	Convey("The concepts list should be get'able", t, func() {
		req, _ := http.NewRequest("GET", "/api/concepts", nil)
		response := httptest.NewRecorder()
		a.Router.ServeHTTP(response, req)

		Convey("The server should respond with StatusOK", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})
	})
}
