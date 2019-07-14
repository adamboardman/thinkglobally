package server

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"github.com/adamboardman/thinkglobally/store"
	. "github.com/smartystreets/goconvey/convey"
	"golang.org/x/crypto/argon2"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strconv"
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
		const verification = "5678"
		a.Store.PurgeUser(emailAddress)

		salt := RandomBytes(16)
		verificationKey := argon2.IDKey([]byte(verification), salt, 1, 64*1024, 4, 32)
		user := store.User{
			Email:           emailAddress,
			Salt:            base64.StdEncoding.EncodeToString(salt),
			ConfirmVerifier: base64.StdEncoding.EncodeToString(verificationKey),
		}
		_, _ = a.Store.InsertUser(&user)

		Convey("The user confirms email address and is redirected to the web app", func() {
			data := url.Values{}
			data.Set("email", emailAddress)
			data.Set("verification", base64.StdEncoding.EncodeToString([]byte(verification)))
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
		_, _ = a.Store.UpdateUser(user)

		response := loginToUser(emailAddress)

		Convey("Login should succeed", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})

		token := userTokenFromLoginResponse(response)

		Convey("Attempt to read user profile", func() {
			req, _ := http.NewRequest("GET", "/api/users/"+uintToString(user.ID), nil)
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
		_, _ = a.Store.UpdateUser(user)

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
		salt := RandomBytes(16)
		encrypted := argon2.IDKey([]byte("1234"), salt, 1, 64*1024, 4, 32)
		user = &store.User{
			Email:     emailAddress,
			Salt:      base64.StdEncoding.EncodeToString(salt),
			Password:  base64.StdEncoding.EncodeToString(encrypted),
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
			body, err := ioutil.ReadAll(response.Body)
			So(err, ShouldBeNil)
			responseData := new([]store.Concept)
			err = json.Unmarshal(body, responseData)
			So(err, ShouldBeNil)
		})
	})
}

func TestConceptTagsList(t *testing.T) {
	Convey("The concept tags list should be get'able", t, func() {
		req, _ := http.NewRequest("GET", "/api/concept_tags", nil)
		response := httptest.NewRecorder()
		a.Router.ServeHTTP(response, req)

		Convey("The server should respond with StatusOK", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
			body, err := ioutil.ReadAll(response.Body)
			So(err, ShouldBeNil)
			responseData := new([]store.ConceptTag)
			err = json.Unmarshal(body, responseData)
			So(err, ShouldBeNil)
		})
	})
}

func TestConceptTagsListForConcept(t *testing.T) {
	concept := ensureTestConceptExists("testConcept")

	Convey("The concept tags list should be get'able", t, func() {
		req, _ := http.NewRequest("GET", "/api/concepts/"+uintToString(concept.ID)+"/tags", nil)
		response := httptest.NewRecorder()
		a.Router.ServeHTTP(response, req)

		Convey("The server should respond with StatusOK", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
			body, err := ioutil.ReadAll(response.Body)
			So(err, ShouldBeNil)
			responseData := new([]store.ConceptTag)
			err = json.Unmarshal(body, responseData)
			So(err, ShouldBeNil)
		})
	})
}

func ensureTestConceptExists(name string) *store.Concept {
	concept, err := a.Store.FindConcept(name)
	if err != nil {
		concept = &store.Concept{
			Name:    name,
			Summary: "a short version of the test concept",
		}
		_, _ = a.Store.InsertConcept(concept)
	}
	return concept
}

func TestAddTagToConceptAsUserShouldFail(t *testing.T) {
	concept := ensureTestConceptExists("testConcept")

	Convey("Given a test user", t, func() {
		const emailAddress = "test-login@example.com"
		ensureTestUserExists(emailAddress)

		tagTag := "LETS"
		a.Store.PurgeConceptTag(tagTag)

		Convey("The user logs in", func() {
			response := loginToUser(emailAddress)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Add a concept tag", func() {
				conceptTagJSON := ConceptTagJSON{}
				conceptTagJSON.Tag = tagTag
				conceptTagJSON.ConceptId = concept.ID
				data, _ := json.Marshal(conceptTagJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/concept_tags", post_data)
				req2.Header.Set("Content-Type", "application/x-www-form-urlencoded")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with error", func() {
					So(response2.Code, ShouldEqual, http.StatusForbidden)

					tags, err := a.Store.ListConceptTags()
					So(err, ShouldBeNil)

					found := checkArrayForConceptTag(tags, tagTag)
					So(found, ShouldBeFalse)
				})
			})
		})
	})
}

func TestAddTagToConceptAsAdmin(t *testing.T) {
	concept := ensureTestConceptExists("testConcept")

	Convey("Given a test user", t, func() {
		const emailAddress = "test-admin@example.com"
		user := ensureTestUserExists(emailAddress)
		user.Permissions = store.UserPermissionsEditor
		_, _ = a.Store.UpdateUser(user)

		tagTag := "LETS"
		a.Store.PurgeConceptTag(tagTag)

		Convey("The user logs in", func() {
			response := loginToUser(emailAddress)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Add a concept tag", func() {
				conceptTagJSON := ConceptTagJSON{}
				conceptTagJSON.Tag = tagTag
				conceptTagJSON.ConceptId = concept.ID
				data, _ := json.Marshal(conceptTagJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/concept_tags", post_data)
				req2.Header.Set("Content-Type", "application/x-www-form-urlencoded")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the tag should be added", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					tags, err := a.Store.ListConceptTags()
					So(err, ShouldBeNil)

					found := checkArrayForConceptTag(tags, tagTag)
					So(found, ShouldBeTrue)
				})
			})
		})
	})
}

func checkArrayForConceptTag(tags []store.ConceptTag, tagTag string) bool {
	found := false
	for _, tag := range tags {
		if tag.Tag == tagTag {
			found = true
		}
	}
	return found
}

func uintToString(id uint) string {
	return strconv.FormatUint(uint64(id), 10)
}

func TestDeleteTagAsUserFails(t *testing.T) {
	Convey("Given a test user", t, func() {
		const emailAddress = "test-login@example.com"
		ensureTestUserExists(emailAddress)

		tagTag := "LETS"
		a.Store.PurgeConceptTag(tagTag)
		concept := ensureTestConceptExists("testConcept")
		conceptTag := store.ConceptTag{
			Tag: tagTag,
			ConceptId: concept.ID,
		}
		conceptTagId, err := a.Store.InsertConceptTag(&conceptTag)
		So(err, ShouldBeNil)

		Convey("The user logs in", func() {
			response := loginToUser(emailAddress)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Delete tag", func() {
				req2, _ := http.NewRequest("DELETE", "/api/concept_tags/"+uintToString(conceptTagId), nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusForbidden", func() {
					So(response2.Code, ShouldEqual, http.StatusForbidden)
				})
			})
		})
	})
}

func TestDeleteTagAsAdmin(t *testing.T) {
	Convey("Given a test user", t, func() {
		const emailAddress = "test-admin@example.com"
		user := ensureTestUserExists(emailAddress)
		user.Permissions = store.UserPermissionsEditor
		_, _ = a.Store.UpdateUser(user)

		tagTag := "LETS"
		a.Store.PurgeConceptTag(tagTag)
		concept := ensureTestConceptExists("testConcept")
		conceptTag := store.ConceptTag{
			Tag: tagTag,
			ConceptId: concept.ID,
		}
		conceptTagId, err := a.Store.InsertConceptTag(&conceptTag)
		So(err, ShouldBeNil)

		Convey("The user logs in", func() {
			response := loginToUser(emailAddress)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Delete tag", func() {
				req2, _ := http.NewRequest("DELETE", "/api/concept_tags/"+uintToString(conceptTagId), nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusOK and the tag should be removed", func() {
					So(response2.Code, ShouldEqual, http.StatusOK)

					conceptTags, err := a.Store.ListConceptTags()
					So(err, ShouldBeNil)

					found := checkArrayForConceptTag(conceptTags, tagTag)
					So(found, ShouldBeFalse)
				})
			})
		})
	})
}
