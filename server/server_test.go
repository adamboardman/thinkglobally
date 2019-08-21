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
	"time"
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
			req, _ := http.NewRequest("POST", "/api/auth/register", postData)
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
		req, _ := http.NewRequest("GET", "/api/auth/refresh_token", nil)
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
			req, _ := http.NewRequest("GET", "/api/auth/confirm_email?"+data.Encode(), nil)
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

		response := loginToUserJSON(emailAddress)

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

		response := loginToUserJSON(emailAddress)

		Convey("Login should succeed", func() {
			So(response.Code, ShouldEqual, http.StatusOK)
		})

		token := userTokenFromLoginResponse(response)

		Convey("Should be able to refresh a token", func() {
			req2, _ := http.NewRequest("GET", "/api/auth/refresh_token", nil)
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
	req, _ := http.NewRequest("POST", "/api/auth/login", postData)
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
	req, _ := http.NewRequest("POST", "/api/auth/login", post_data)
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
			response := loginToUserJSON(emailAddress)

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
				req2.Header.Set("Content-Type", "application/json")
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
			response := loginToUserJSON(emailAddress)

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
				req2.Header.Set("Content-Type", "application/json")
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
			Tag:       tagTag,
			ConceptId: concept.ID,
		}
		conceptTagId, err := a.Store.InsertConceptTag(&conceptTag)
		So(err, ShouldBeNil)

		Convey("The user logs in", func() {
			response := loginToUserJSON(emailAddress)

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
			Tag:       tagTag,
			ConceptId: concept.ID,
		}
		conceptTagId, err := a.Store.InsertConceptTag(&conceptTag)
		So(err, ShouldBeNil)

		Convey("The user logs in", func() {
			response := loginToUserJSON(emailAddress)

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

type ApiActionResponse struct {
	Message     string
	ResourceId  uint
	ResourceIds []uint
	Status      uint
}

func TestDeleteTagsAsAdmin(t *testing.T) {
	Convey("Given a test user", t, func() {
		const emailAddress = "test-admin@example.com"
		user := ensureTestUserExists(emailAddress)
		user.Permissions = store.UserPermissionsEditor
		_, _ = a.Store.UpdateUser(user)

		concept := ensureTestConceptExists("testConcept")

		tagTag1 := "LETS"
		a.Store.PurgeConceptTag(tagTag1)
		conceptTag1 := store.ConceptTag{
			Tag:       tagTag1,
			ConceptId: concept.ID,
		}
		conceptTag1Id, err := a.Store.InsertConceptTag(&conceptTag1)
		So(err, ShouldBeNil)

		tagTag2 := "local exchange trading system"
		a.Store.PurgeConceptTag(tagTag2)
		conceptTag2 := store.ConceptTag{
			Tag:       tagTag2,
			ConceptId: concept.ID,
		}
		conceptTag2Id, err := a.Store.InsertConceptTag(&conceptTag2)
		So(err, ShouldBeNil)

		Convey("The user logs in", func() {
			response := loginToUserJSON(emailAddress)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Delete tags", func() {
				var tags [2]uint
				tags[0] = conceptTag1Id
				tags[1] = conceptTag2Id
				data, _ := json.Marshal(tags)
				post_data := bytes.NewReader(data)

				req2, _ := http.NewRequest("DELETE", "/api/concept_tags", post_data)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusOK and the tags should be removed", func() {
					So(response2.Code, ShouldEqual, http.StatusOK)
					body, err := ioutil.ReadAll(response2.Body)
					So(err, ShouldBeNil)
					responseData := new(ApiActionResponse)
					err = json.Unmarshal(body, responseData)
					So(err, ShouldBeNil)

					So (responseData.ResourceIds[0], ShouldEqual, conceptTag1Id)
					So (responseData.ResourceIds[1], ShouldEqual, conceptTag2Id)

					conceptTags, err := a.Store.ListConceptTags()
					So(err, ShouldBeNil)

					found1 := checkArrayForConceptTag(conceptTags, tagTag1)
					So(found1, ShouldBeFalse)
					found2 := checkArrayForConceptTag(conceptTags, tagTag2)
					So(found2, ShouldBeFalse)
				})
			})
		})
	})
}

func checkArrayForTransaction(transactions []store.Transaction, transactionJson TransactionJSON) bool {
	found := false
	for _, transaction := range transactions {
		if transaction.Status == transactionJson.Status && transaction.FromUserId == transactionJson.FromUserId && transaction.Seconds == transactionJson.Seconds && transaction.Multiplier == transactionJson.Multiplier && transaction.ToUserId == transactionJson.ToUserId {
			found = true
		}
	}
	return found
}

func TestCreateTransactionOffer(t *testing.T) {
	Convey("Given a test user origin and recipient", t, func() {
		const emailAddressOrigin = "test-user1@example.com"
		user1 := ensureTestUserExists(emailAddressOrigin)
		user1.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user1)
		const emailAddressRecipient = "test-user2@example.com"
		user2 := ensureTestUserExists(emailAddressRecipient)
		user2.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user2)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(emailAddressOrigin)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Offer transaction", func() {
				transactionJSON := TransactionJSON{}
				transactionJSON.FromUserId = user1.ID
				transactionJSON.ToUserId = user2.ID
				transactionJSON.Status = store.TransactionOffered
				transactionJSON.Seconds = 30 * 60
				transactionJSON.Multiplier = 1
				data, _ := json.Marshal(transactionJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/transactions", post_data)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be created", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					userTransactions, err := a.Store.ListTransactionsForUser(user1.ID)
					So(err, ShouldBeNil)

					found := checkArrayForTransaction(userTransactions, transactionJSON)
					So(found, ShouldBeTrue)
				})
			})
		})
	})
}

func TestCreateTransactionOfferAsSomeoneElse(t *testing.T) {
	Convey("Given a test user origin and recipient", t, func() {
		const emailAddressUser = "test-user@example.com"
		user := ensureTestUserExists(emailAddressUser)
		user.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user)
		const emailAddressFakeOrigin = "test-user1@example.com"
		user1 := ensureTestUserExists(emailAddressFakeOrigin)
		user1.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user1)
		const emailAddressRecipient = "test-user2@example.com"
		user2 := ensureTestUserExists(emailAddressRecipient)
		user2.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user2)

		Convey("The user logs in", func() {
			response := loginToUserJSON(emailAddressUser)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Offer transaction", func() {
				transactionJSON := TransactionJSON{}
				transactionJSON.FromUserId = user1.ID
				transactionJSON.ToUserId = user2.ID
				transactionJSON.Status = store.TransactionOffered
				transactionJSON.Seconds = 30 * 60
				transactionJSON.Multiplier = 1
				ClearTransactionsMatchingJSON(transactionJSON)
				data, _ := json.Marshal(transactionJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/transactions", post_data)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusBadRequest and the transaction should not be created", func() {
					So(response2.Code, ShouldEqual, http.StatusBadRequest)

					userTransactions, err := a.Store.ListTransactionsForUser(user1.ID)
					So(err, ShouldBeNil)

					found := checkArrayForTransaction(userTransactions, transactionJSON)
					So(found, ShouldBeFalse)
				})
			})
		})
	})
}

func TestCreateTransactionRequest(t *testing.T) {
	Convey("Given a test user origin and recipient", t, func() {
		const emailAddressOrigin = "test-user1@example.com"
		user1 := ensureTestUserExists(emailAddressOrigin)
		user1.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user1)
		const emailAddressRecipient = "test-user2@example.com"
		user2 := ensureTestUserExists(emailAddressRecipient)
		user2.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user2)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(emailAddressRecipient)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Request transaction", func() {
				transactionJSON := TransactionJSON{}
				transactionJSON.FromUserId = user1.ID
				transactionJSON.ToUserId = user2.ID
				transactionJSON.Status = store.TransactionRequested
				transactionJSON.Seconds = 30 * 60
				transactionJSON.Multiplier = 1
				ClearTransactionsMatchingJSON(transactionJSON)
				data, _ := json.Marshal(transactionJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/transactions", post_data)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be created", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					userTransactions, err := a.Store.ListTransactionsForUser(user1.ID)
					So(err, ShouldBeNil)

					found := checkArrayForTransaction(userTransactions, transactionJSON)
					So(found, ShouldBeTrue)
				})
			})
		})
	})
}

func TestCreateTransactionRequestAsSomeoneElse(t *testing.T) {
	Convey("Given a test user origin and recipient", t, func() {
		const emailAddressUser = "test-user@example.com"
		user := ensureTestUserExists(emailAddressUser)
		user.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user)
		const emailAddressOrigin = "test-user1@example.com"
		user1 := ensureTestUserExists(emailAddressOrigin)
		user1.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user1)
		const emailAddressRecipient = "test-user2@example.com"
		user2 := ensureTestUserExists(emailAddressRecipient)
		user2.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user2)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(emailAddressUser)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Request transaction", func() {
				transactionJSON := TransactionJSON{}
				transactionJSON.FromUserId = user1.ID
				transactionJSON.ToUserId = user2.ID
				transactionJSON.Status = store.TransactionRequested
				transactionJSON.Seconds = 30 * 60
				transactionJSON.Multiplier = 1
				ClearTransactionsMatchingJSON(transactionJSON)
				data, _ := json.Marshal(transactionJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/transactions", post_data)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusBadRequest and the transaction should be created", func() {
					So(response2.Code, ShouldEqual, http.StatusBadRequest)

					userTransactions, err := a.Store.ListTransactionsForUser(user1.ID)
					So(err, ShouldBeNil)

					found := checkArrayForTransaction(userTransactions, transactionJSON)
					So(found, ShouldBeFalse)
				})
			})
		})
	})
}

func ClearTransactionsMatchingJSON(transactionJson TransactionJSON) {
	userTransactions, _ := a.Store.ListTransactionsForUser(transactionJson.FromUserId)

	for _, transaction := range userTransactions {
		if transaction.Status == transactionJson.Status && transaction.FromUserId == transactionJson.FromUserId && transaction.Seconds == transactionJson.Seconds && transaction.Multiplier == transactionJson.Multiplier && transaction.ToUserId == transactionJson.ToUserId {
			a.Store.PurgeTransaction(transaction)
		}
	}
}

func ClearTransactionsMatching(transaction store.Transaction) {
	userTransactions, _ := a.Store.ListTransactionsForUser(transaction.FromUserId)

	for _, transaction := range userTransactions {
		if transaction.Status == transaction.Status && transaction.FromUserId == transaction.FromUserId && transaction.Seconds == transaction.Seconds && transaction.Multiplier == transaction.Multiplier && transaction.ToUserId == transaction.ToUserId {
			a.Store.PurgeTransaction(transaction)
		}
	}
}

func TestAcceptTransactionOffer(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionOffered,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The user2 logs in", func() {
			response := loginToUserJSON(user2.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/accept", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be approved", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionOfferApproved)
					So(approvedTransaction.FromUserBalance, ShouldEqual, -(1*60*60 + 1))
					So(approvedTransaction.ToUserBalance, ShouldEqual, (1 * 60 * 60))
					So(time.Time(approvedTransaction.ConfirmedDate).After(time.Time(approvedTransaction.InitiatedDate)), ShouldBeTrue)
				})
			})
		})
	})
}

func TestAcceptTransactionOfferAsOtherUser(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionOffered,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The other user logs in", func() {
			const emailAddressUser = "test-user@example.com"
			user := ensureTestUserExists(emailAddressUser)
			user.Permissions = store.UserPermissionsUser
			_, _ = a.Store.UpdateUser(user)
			response := loginToUserJSON(emailAddressUser)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/accept", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusForbidden and the transaction should not be approved", func() {
					So(response2.Code, ShouldEqual, http.StatusForbidden)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionOffered)
				})
			})
		})
	})
}

func TestRejectTransactionOffer(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionOffered,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The user2 logs in", func() {
			response := loginToUserJSON(user2.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/reject", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be rejected", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionOfferRejected)
					So(time.Time(approvedTransaction.ConfirmedDate).After(time.Time(approvedTransaction.InitiatedDate)), ShouldBeTrue)
				})
			})
		})
	})
}

func TestRejectTransactionOfferAsOtherUser(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionOffered,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The other user logs in", func() {
			const emailAddressUser = "test-user@example.com"
			user := ensureTestUserExists(emailAddressUser)
			user.Permissions = store.UserPermissionsUser
			_, _ = a.Store.UpdateUser(user)
			response := loginToUserJSON(emailAddressUser)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/reject", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusForbidden and the transaction should not be approved", func() {
					So(response2.Code, ShouldEqual, http.StatusForbidden)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionOffered)
				})
			})
		})
	})
}

func TestAcceptTransactionRequest(t *testing.T) {
	Convey("Given a transaction request", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionRequested,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(user1.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/accept", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be approved", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionRequestApproved)
					So(approvedTransaction.FromUserBalance, ShouldEqual, -(1 * 60 * 60))
					So(approvedTransaction.ToUserBalance, ShouldEqual, (1*60*60)-1)
				})
			})
		})
	})
}

func TestAcceptTransactionRequestAsOtherUser(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionRequested,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The other user logs in", func() {
			const emailAddressUser = "test-user@example.com"
			user := ensureTestUserExists(emailAddressUser)
			user.Permissions = store.UserPermissionsUser
			_, _ = a.Store.UpdateUser(user)
			response := loginToUserJSON(emailAddressUser)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/accept", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusForbidden and the transaction should not be approved", func() {
					So(response2.Code, ShouldEqual, http.StatusForbidden)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionRequested)
				})
			})
		})
	})
}

func TestRejectTransactionRequest(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionRequested,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(user1.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/reject", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be rejected", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionRequestRejected)
				})
			})
		})
	})
}

func TestRejectTransactionRequestAsOtherUser(t *testing.T) {
	Convey("Given a transaction offer", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionRequested,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The other user logs in", func() {
			const emailAddressUser = "test-user@example.com"
			user := ensureTestUserExists(emailAddressUser)
			user.Permissions = store.UserPermissionsUser
			_, _ = a.Store.UpdateUser(user)
			response := loginToUserJSON(emailAddressUser)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Accept transaction", func() {
				req2, _ := http.NewRequest("PATCH", "/api/transactions/"+uintToString(transactionId)+"/reject", nil)
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusForbidden and the transaction should not be approved", func() {
					So(response2.Code, ShouldEqual, http.StatusForbidden)

					approvedTransaction, err := a.Store.LoadTransaction(transactionId)
					So(err, ShouldBeNil)
					So(approvedTransaction.Status, ShouldEqual, store.TransactionRequested)
				})
			})
		})
	})
}

func TestCreateTransactionRequestToEmailAddress(t *testing.T) {
	Convey("Given a test user origin and recipient", t, func() {
		const emailAddressOrigin = "test-user1@example.com"
		user1 := ensureTestUserExists(emailAddressOrigin)
		user1.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user1)
		const emailAddressRecipient = "test-user2@example.com"
		user2 := ensureTestUserExists(emailAddressRecipient)
		user2.Permissions = store.UserPermissionsUser
		_, _ = a.Store.UpdateUser(user2)

		Convey("The user2 logs in", func() {
			response := loginToUserJSON(user2.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Request transaction", func() {
				transactionJSON := TransactionJSON{}
				transactionJSON.FromUserId = 0
				transactionJSON.ToUserId = user2.ID
				transactionJSON.Email = user1.Email
				transactionJSON.Status = store.TransactionRequested
				transactionJSON.Seconds = 30 * 60
				transactionJSON.Multiplier = 1
				ClearTransactionsMatchingJSON(transactionJSON)
				data, _ := json.Marshal(transactionJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/transactions", post_data)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be created", func() {
					So(response2.Code, ShouldEqual, http.StatusCreated)

					userTransactions, err := a.Store.ListTransactionsForUser(user2.ID)
					So(err, ShouldBeNil)

					transactionJSON.FromUserId = user1.ID
					found := checkArrayForTransaction(userTransactions, transactionJSON)
					So(found, ShouldBeTrue)
				})
			})
		})
	})
}

func TestListTxUsers(t *testing.T) {
	Convey("Given a test user origin and recipient with a transaction", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionRequested,
		}
		ClearTransactionsMatching(transaction)
		_, _ = a.Store.InsertTransaction(&transaction)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(user1.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("List transactions", func() {
				req2, _ := http.NewRequest("GET", "/api/users", nil)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusOK and the users involved in the transaction should be listed", func() {
					So(response2.Code, ShouldEqual, http.StatusOK)
					body, err := ioutil.ReadAll(response2.Body)
					So(err, ShouldBeNil)
					responseData := new([]store.PublicUser)
					err = json.Unmarshal(body, responseData)
					So(err, ShouldBeNil)

					So((*responseData)[0].ID, ShouldEqual, user1.ID)
					So((*responseData)[1].ID, ShouldEqual, user2.ID)
				})
			})
		})
	})
}

func TestListTransactions(t *testing.T) {
	Convey("Given a test user origin and recipient with a transaction", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")
		user2 := ensureTestUserExists("test-user2@example.com")
		transaction := store.Transaction{
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			InitiatedDate: store.PosixDateTime(time.Now()),
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test Transaction",
			Status:        store.TransactionRequested,
		}
		ClearTransactionsMatching(transaction)
		transactionId, _ := a.Store.InsertTransaction(&transaction)

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(user1.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("List transactions", func() {
				req2, _ := http.NewRequest("GET", "/api/transactions", nil)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusOK and the transaction should be listed", func() {
					So(response2.Code, ShouldEqual, http.StatusOK)
					body, err := ioutil.ReadAll(response2.Body)
					So(err, ShouldBeNil)
					responseData := new([]store.Transaction)
					err = json.Unmarshal(body, responseData)
					So(err, ShouldBeNil)

					So((*responseData)[0].ID, ShouldEqual, transactionId)
				})
			})
		})
	})
}

func TestRejectTransactionFromToSameUser(t *testing.T) {
	Convey("Given a test user origin and recipient", t, func() {
		user1 := ensureTestUserExists("test-user1@example.com")

		Convey("The user1 logs in", func() {
			response := loginToUserJSON(user1.Email)

			Convey("The server should respond with StatusOK", func() {
				So(response.Code, ShouldEqual, http.StatusOK)
			})

			token := userTokenFromLoginResponse(response)

			Convey("Offer transaction", func() {
				transactionJSON := TransactionJSON{}
				transactionJSON.FromUserId = user1.ID
				transactionJSON.ToUserId = user1.ID
				transactionJSON.Status = store.TransactionOffered
				transactionJSON.Seconds = 30 * 60
				transactionJSON.Multiplier = 1
				data, _ := json.Marshal(transactionJSON)
				post_data := bytes.NewReader(data)
				req2, _ := http.NewRequest("POST", "/api/transactions", post_data)
				req2.Header.Set("Content-Type", "application/json")
				req2.Header.Set("Authorization", "Bearer "+token)
				response2 := httptest.NewRecorder()
				a.Router.ServeHTTP(response2, req2)

				Convey("The server should respond with StatusCreated and the transaction should be created", func() {
					So(response2.Code, ShouldEqual, http.StatusBadRequest)

					userTransactions, err := a.Store.ListTransactionsForUser(user1.ID)
					So(err, ShouldBeNil)

					found := checkArrayForTransaction(userTransactions, transactionJSON)
					So(found, ShouldBeFalse)
				})
			})
		})
	})
}
