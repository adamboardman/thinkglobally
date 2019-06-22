package store

import (
	. "github.com/smartystreets/goconvey/convey"
	"golang.org/x/crypto/bcrypt"
	"os"
	"testing"
)

var s Store

func TestMain(m *testing.M) {
	s = Store{}
	s.StoreInit("test-db")

	code := m.Run()

	_ = s.db.Close()
	os.Exit(code)
}

func ensureTestUserExists(emailAddress string) *User {
	user, err := s.FindUser(emailAddress)
	if err != nil {
		encrypted, err := bcrypt.GenerateFromPassword([]byte("1234"), 13)
		So(err, ShouldBeNil)
		user = &User{
			Email:     emailAddress,
			Password:  string(encrypted),
			Confirmed: true,
		}
		s.InsertUser(user)
	}
	return user
}

func TestStore_DoubleInsertUser(t *testing.T) {
	const emailAddress = "joe@example.com"
	Convey("Insert a user to the store", t, func() {
		s.PurgeUser(emailAddress)
		user := User{Email: emailAddress}
		user.FirstName = "Joe"
		user.LastName = "Blogs"
		userId, _ := s.InsertUser(&user)

		Convey("User should be given an ID", func() {
			So(userId, ShouldBeGreaterThan, 0)
		})

		Convey("Insert the same email again", func() {
			user2 := User{Email: emailAddress}
			user2.FirstName = "John"
			user2.LastName = "Smith"
			user2Id, err := s.InsertUser(&user2)

			Convey("Expect Error and No UserId", func() {
				So(err, ShouldNotBeNil)
				So(user2Id, ShouldEqual, 0)
			})
		})

	})
}

func TestStore_InsertConcept(t *testing.T) {
	const name = "test"
	Convey("Insert a concept to the store", t, func() {
		s.PurgeConcept(name)
		concept := Concept{Name: name}
		concept.Summary = "a short version of the test concept"
		conceptId, _ := s.InsertConcept(&concept)

		Convey("Concept should be given an ID", func() {
			So(conceptId, ShouldBeGreaterThan, 0)
		})

		Convey("ConceptList should contain concept", func() {
			concepts, _ := s.ListConcepts()
			So(len(concepts), ShouldBeGreaterThan, 0)
		})

		Convey("Concept should be findable by name", func() {
			savedConcept, _ := s.LoadConcept(conceptId)
			Convey("User should match except for userID", func() {
				So(savedConcept.Name, ShouldEqual, concept.Name)
				So(savedConcept.Summary, ShouldEqual, concept.Summary)
				So(savedConcept.Full, ShouldEqual, concept.Full)
			})

			Convey("Updating the concept", func() {
				savedConcept.Summary = "a different short version"
				conceptId2, _ := s.UpdateConcept(savedConcept)
				Convey("Concept should keep the same ID and content", func() {
					So(conceptId2, ShouldEqual, conceptId)
					reloadedConcept, _ := s.FindConcept(name)
					So(reloadedConcept.ID, ShouldEqual, savedConcept.ID)
					So(reloadedConcept.Name, ShouldEqual, savedConcept.Name)
					So(reloadedConcept.Summary, ShouldEqual, savedConcept.Summary)
					So(reloadedConcept.Full, ShouldEqual, savedConcept.Full)
				})
			})
		})
	})
}

func TestStore_DeleteConcept(t *testing.T) {
	const name = "test"
	Convey("Given that we have saved a user", t, func() {
		s.PurgeConcept(name)
		concept := Concept{Name: name}
		conceptId, _ := s.InsertConcept(&concept)

		Convey("Concept should be given an ID", func() {
			So(conceptId, ShouldBeGreaterThan, 0)
		})

		Convey("Then I delete the concept", func() {
			s.PurgeConcept(name)

			Convey("Concept should not be findable by email address", func() {
				savedUser, err := s.FindConcept(name)

				So(err, ShouldNotBeNil)
				So(savedUser, ShouldEqual, nil)
			})
		})
	})
}

func TestStore_AddNameToConcept(t *testing.T) {
	const name = "test"
	const altName = "test2"
	Convey("Insert a concept to the store", t, func() {
		s.PurgeConcept(name)
		concept := Concept{Name: name}
		concept.Summary = "a short version of the test concept"
		conceptId, _ := s.InsertConcept(&concept)

		Convey("Concept should be given an ID", func() {
			So(conceptId, ShouldBeGreaterThan, 0)
		})

		Convey("Add Alt Name", func() {
			conceptAltName := ConceptAltName{AltName:altName, ConceptId:conceptId, Order:0}
			conceptAltNameId, _ := s.InsertConceptAltName(&conceptAltName)

			Convey("ConceptAltName should be given an ID", func() {
				So(conceptAltNameId, ShouldBeGreaterThan, 0)
			})

			Convey("Concept names list should contain both names", func() {
				altNames, _ := s.ConceptAltNames(&concept)
				So(len(altNames), ShouldEqual, 2)
				So(altNames[0], ShouldEqual, name)
				So(altNames[1], ShouldEqual, altName)
			})
		})
	})
}

