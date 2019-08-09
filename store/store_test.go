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
		_, _ = s.InsertUser(user)
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

		Convey("Concepts list should contain concept", func() {
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

func TestStore_AddTagsToConcept(t *testing.T) {
	const name = "test"
	const tag1 = "tag1"
	const tag2 = "tag2"
	Convey("Insert a concept to the store", t, func() {
		s.PurgeConcept(name)
		concept := Concept{Name: name}
		concept.Summary = "a short version of the test concept"
		conceptId, _ := s.InsertConcept(&concept)

		Convey("Concept should be given an ID", func() {
			So(conceptId, ShouldBeGreaterThan, 0)
		})

		Convey("Add Tag", func() {
			conceptTag1 := ConceptTag{Tag: tag1, ConceptId: conceptId, Order: 0}
			conceptTag2 := ConceptTag{Tag: tag2, ConceptId: conceptId, Order: 1}
			conceptTag1Id, _ := s.InsertConceptTag(&conceptTag1)
			conceptTag2Id, _ := s.InsertConceptTag(&conceptTag2)

			Convey("conceptTags should be given an ID", func() {
				So(conceptTag1Id, ShouldBeGreaterThan, 0)
				So(conceptTag2Id, ShouldBeGreaterThan, 0)
			})

			Convey("Concept tags list should contain both names", func() {
				tags, _ := s.ConceptTagsAsStrings(&concept)
				So(len(tags), ShouldEqual, 2)
				So(tags[0], ShouldEqual, tag1)
				So(tags[1], ShouldEqual, tag2)
			})
		})
	})
}

func ensureTestConceptExists(name string) *Concept {
	concept, err := s.FindConcept(name)
	if err != nil {
		concept = &Concept{
			Name:    name,
			Summary: "a short version of the test concept",
		}
		_, _ = s.InsertConcept(concept)
	}
	return concept
}

func TestStore_ListAllTags(t *testing.T) {
	const tagA = "tagA"
	const tagB = "tagB"
	const tagC = "tagC"
	s.PurgeConceptTag(tagA)
	s.PurgeConceptTag(tagB)
	s.PurgeConceptTag(tagC)
	concept := ensureTestConceptExists("testConcept")
	Convey("Create some tags", t, func() {
		conceptTagA := ConceptTag{Tag: tagA, ConceptId: concept.ID, Order: 0}
		conceptTagB := ConceptTag{Tag: tagB, ConceptId: concept.ID, Order: 1}
		conceptTagC := ConceptTag{Tag: tagC, ConceptId: concept.ID, Order: 1}
		conceptTagAId, _ := s.InsertConceptTag(&conceptTagA)
		conceptTagBId, _ := s.InsertConceptTag(&conceptTagB)
		conceptTagCId, _ := s.InsertConceptTag(&conceptTagC)
		Convey("All tags list should contain items", func() {
			tags, _ := s.ListConceptTags()
			tagAFromTags := getTagFromTags(tags, tagA)
			So(tagAFromTags.Tag, ShouldEqual, tagA)
			So(tagAFromTags.ID, ShouldEqual, conceptTagAId)
			tagBFromTags := getTagFromTags(tags, tagB)
			So(tagBFromTags.Tag, ShouldEqual, tagB)
			So(tagBFromTags.ID, ShouldEqual, conceptTagBId)
			tagCFromTags := getTagFromTags(tags, tagC)
			So(tagCFromTags.Tag, ShouldEqual, tagC)
			So(tagCFromTags.ID, ShouldEqual, conceptTagCId)
		})
	})
}

func getTagFromTags(tags []ConceptTag, tag string) *ConceptTag {
	for _, conceptTag := range tags {
		if conceptTag.Tag == tag {
			return &conceptTag
		}
	}
	return nil
}

func TestStore_InvalidTagCreationFail(t *testing.T) {
	const tagInvalid = "tagInvalid"
	Convey("Create some tags", t, func() {
		conceptTagInvalid := ConceptTag{Tag: tagInvalid, ConceptId: 0, Order: 0}
		conceptTagInvalidId, _ := s.InsertConceptTag(&conceptTagInvalid)
		Convey("Invalid tag should not be created", func() {
			So(conceptTagInvalidId, ShouldEqual, 0)
		})
		Convey("All tags list should not contain invalid tag", func() {
			tags, _ := s.ListConceptTags()
			tagInvalidFromTags := getTagFromTags(tags, tagInvalid)
			So(tagInvalidFromTags, ShouldEqual, nil)
		})
	})
}

func getTransactionFromTransactions(transactions []Transaction, id uint) *Transaction {
	for _, transaction := range transactions {
		if transaction.ID == id {
			return &transaction
		}
	}
	return nil
}

func TestStore_TransactionCreation(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		s.db.Unscoped().Where("from_user_id=?", user1.ID).Delete(Transaction{})
		s.db.Unscoped().Where("to_user_id=?", user1.ID).Delete(Transaction{})
		user2 := ensureTestUserExists("user2@example.com")
		s.db.Unscoped().Where("from_user_id=?", user2.ID).Delete(Transaction{})
		s.db.Unscoped().Where("to_user_id=?", user2.ID).Delete(Transaction{})
		transaction := Transaction{
			FromUserId:  user1.ID,
			ToUserId:    user2.ID,
			Seconds:     1 * 60 * 60,
			Commission:  1,
			Multiplier:  1,
			Description: "Test Transaction",
			Status:      TransactionOffered,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Transaction should be created", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions.ID, ShouldEqual, transactionId)


			Convey("Updating the transaction", func() {
				transactionFromTransactions.Status = TransactionOfferApproved
				transactionId2, _ := s.UpdateTransaction(transactionFromTransactions)
				Convey("Concept should keep the same ID and content", func() {
					So(transactionId2, ShouldEqual, transactionId)
					reloadedTransaction, _ := s.LoadTransaction(transactionId2)
					So(reloadedTransaction.ID, ShouldEqual, transactionFromTransactions.ID)
					So(reloadedTransaction.FromUserId, ShouldEqual, transactionFromTransactions.FromUserId)
					So(reloadedTransaction.ToUserId, ShouldEqual, transactionFromTransactions.ToUserId)
					So(reloadedTransaction.Status, ShouldEqual, transactionFromTransactions.Status)
				})
			})
		})
	})
}

func TestStore_TransactionRejectNoUser(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		transaction := Transaction{
			FromUserId:  user1.ID,
			ToUserId:    0,
			Seconds:     1 * 60 * 60,
			Commission:  1,
			Multiplier:  1,
			Description: "Test Transaction",
			Status:      TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Invalid transaction should not be created", func() {
			So(transactionId, ShouldEqual, 0)
		})
		Convey("Invalid transaction should not be in list", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions, ShouldEqual, nil)
		})
	})
}

func TestStore_TransactionRejectTooSmallMultipler(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		user2 := ensureTestUserExists("user2@example.com")
		transaction := Transaction{
			FromUserId:  user1.ID,
			ToUserId:    user2.ID,
			Seconds:     1 * 60 * 60,
			Commission:  1,
			Multiplier:  0.99,
			Description: "Test Transaction",
			Status:      TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Invalid transaction should not be created", func() {
			So(transactionId, ShouldEqual, 0)
		})
		Convey("Invalid transaction should not be in list", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions, ShouldEqual, nil)
		})
	})
}

func TestStore_TransactionRejectTooBigMultiplier(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		user2 := ensureTestUserExists("user2@example.com")
		transaction := Transaction{
			FromUserId:  user1.ID,
			ToUserId:    user2.ID,
			Seconds:     1 * 60 * 60,
			Commission:  1,
			Multiplier:  3.0001,
			Description: "Test Transaction",
			Status:      TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Invalid transaction should not be created", func() {
			So(transactionId, ShouldEqual, 0)
		})
		Convey("Invalid transaction should not be in list", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions, ShouldEqual, nil)
		})
	})
}
