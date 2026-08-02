package store

import (
	"os"
	"testing"
	"time"

	. "github.com/smartystreets/goconvey/convey"
	"golang.org/x/crypto/bcrypt"
)

var s Store

func TestMain(m *testing.M) {
	s = Store{}
	s.StoreInit()

	code := m.Run()

	os.Exit(code)
}

func ensureTestUserExists(emailAddress string) *User {
	user, err := s.FindUser(emailAddress)
	if err != nil {
		encrypted, err := bcrypt.GenerateFromPassword([]byte("1234"), 13)
		So(err, ShouldBeNil)
		user = &User{
			Password: string(encrypted),
			PrivilegedUser: PrivilegedUser{
				PublicUser: PublicUser{
					Email: emailAddress,
				},
				Confirmed: true,
			},
		}
		_, _ = s.InsertUser(user)
	}
	return user
}

func TestStore_DoubleInsertUser(t *testing.T) {
	const emailAddress = "joe@example.com"
	Convey("Insert a user to the store", t, func() {
		s.PurgeUser(emailAddress)
		user := User{}
		user.Email = emailAddress
		user.FirstName = "Joe"
		user.LastName = "Blogs"
		userId, _ := s.InsertUser(&user)

		Convey("User should be given an ID", func() {
			So(userId, ShouldBeGreaterThan, 0)
		})

		Convey("Insert the same email again", func() {
			user2 := User{}
			user2.Email = emailAddress
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
				So(savedUser, ShouldEqual, (*Concept)(nil))
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
			So(tagInvalidFromTags, ShouldEqual, (*ConceptTag)(nil))
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
			InitiatedDate: PosixDateTime(time.Now().UTC()),
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test TransactionS1",
			Status:        TransactionOffered,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Transaction should be created", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions.ID, ShouldEqual, transactionId)

			Convey("Updating the transaction", func() {
				transactionFromTransactions.Status = TransactionOfferApproved
				transactionId2, _ := s.UpdateTransaction(transactionFromTransactions)
				Convey("Transaction should keep the same ID and content", func() {
					So(transactionId2, ShouldEqual, transactionId)
					reloadedTransaction, _ := s.LoadTransaction(transactionId2)
					So(reloadedTransaction.ID, ShouldEqual, transactionFromTransactions.ID)
					So(reloadedTransaction.FromUserId, ShouldEqual, transactionFromTransactions.FromUserId)
					So(reloadedTransaction.ToUserId, ShouldEqual, transactionFromTransactions.ToUserId)
					So(reloadedTransaction.Status, ShouldEqual, transactionFromTransactions.Status)
					So(reloadedTransaction.InitiatedDate, ShouldEqual, transactionFromTransactions.InitiatedDate)
					So(reloadedTransaction.ConfirmedDate, ShouldEqual, transactionFromTransactions.ConfirmedDate)
				})
			})
		})
	})
}

func TestStore_TransactionRejectNoUser(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		transaction := Transaction{
			InitiatedDate: PosixDateTime(time.Now().UTC()),
			ConfirmedDate: PosixDateTime(time.Now().UTC()),
			FromUserId:    user1.ID,
			ToUserId:      0,
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    1,
			Description:   "Test TransactionS2",
			Status:        TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Invalid transaction should not be created", func() {
			So(transactionId, ShouldEqual, 0)
		})
		Convey("Invalid transaction should not be in list", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions, ShouldEqual, (*Transaction)(nil))
		})
	})
}

func TestStore_TransactionRejectTooSmallMultipler(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		user2 := ensureTestUserExists("user2@example.com")
		transaction := Transaction{
			InitiatedDate: PosixDateTime(time.Now().UTC()),
			ConfirmedDate: PosixDateTime(time.Now().UTC()),
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    0.99,
			Description:   "Test TransactionS3",
			Status:        TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Invalid transaction should not be created", func() {
			So(transactionId, ShouldEqual, 0)
		})
		Convey("Invalid transaction should not be in list", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions, ShouldEqual, (*Transaction)(nil))
		})
	})
}

func TestStore_TransactionRejectTooBigMultiplier(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		user2 := ensureTestUserExists("user2@example.com")
		transaction := Transaction{
			InitiatedDate: PosixDateTime(time.Now().UTC()),
			ConfirmedDate: PosixDateTime(time.Now().UTC()),
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    3.0001,
			Description:   "Test TransactionS4",
			Status:        TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Invalid transaction should not be created", func() {
			So(transactionId, ShouldEqual, 0)
		})
		Convey("Invalid transaction should not be in list", func() {
			transactions, _ := s.ListTransactionsForUser(user1.ID)
			transactionFromTransactions := getTransactionFromTransactions(transactions, transaction.ID)
			So(transactionFromTransactions, ShouldEqual, (*Transaction)(nil))
		})
	})
}

func TestStore_TransactionPartners(t *testing.T) {
	Convey("Create a transaction", t, func() {
		user1 := ensureTestUserExists("user1@example.com")
		user2 := ensureTestUserExists("user2@example.com")
		transaction := Transaction{
			InitiatedDate: PosixDateTime(time.Now().UTC()),
			ConfirmedDate: PosixDateTime(time.Now().UTC()),
			FromUserId:    user1.ID,
			ToUserId:      user2.ID,
			Seconds:       1 * 60 * 60,
			TxFee:         1,
			Multiplier:    3,
			Description:   "Test TransactionS5",
			Status:        TransactionOfferApproved,
		}
		transactionId, _ := s.InsertTransaction(&transaction)
		Convey("Transaction should be created", func() {
			So(transactionId, ShouldNotEqual, 0)
		})
		Convey("Users list of transaction partners should contain both users", func() {
			users, _ := s.ListTransactionPartners(user1.ID)
			So(users[0].ID, ShouldEqual, user1.ID)
			So(users[1].ID, ShouldEqual, user2.ID)
		})
	})
}

func TestStore_InsertLivingWageLocation(t *testing.T) {
	const name = "UK"
	Convey("Insert a living wage location to the store", t, func() {
		s.PurgeLivingWageLocation(name)
		livingWageLocation := LivingWageLocation{Name: name}
		locationId, _ := s.InsertLivingWageLocation(&livingWageLocation)

		Convey("LivingWageLocation should be given an ID", func() {
			So(locationId, ShouldBeGreaterThan, 0)
		})
		Convey("LivingWageLocations", func() {
			locations, _ := s.ListLivingWageLocations()
			So(len(locations), ShouldBeGreaterThan, 0)
		})
	})
}

func ensureLivingWageLocationExists(locationName string) *LivingWageLocation {
	location, err := s.FindLivingWageLocation(locationName)
	if err != nil {
		location = &LivingWageLocation{
			Name: locationName,
		}
		_, _ = s.InsertLivingWageLocation(location)
	}
	return location
}

func TestStore_InsertLivingWage(t *testing.T) {
	const locationName = "UK"
	Convey("Find or insert living wage to the store", t, func() {
		livingWageLocation := ensureLivingWageLocationExists(locationName)
		start := time.Date(2011, time.January, 1, 0, 0, 0, 0, time.UTC)
		stop := time.Date(2012, time.January, 1, 0, 0, 0, 0, time.UTC)
		foundLivingWage, err := s.FindLivingWage(livingWageLocation.ID, PosixDateTime(start), PosixDateTime(stop))
		if err == nil {
			s.PurgeLivingWage(foundLivingWage)
		}
		livingWage := LivingWage{
			LocationId: livingWageLocation.ID,
			StartDate:  PosixDateTime(start),
			StopDate:   PosixDateTime(stop),
			Wage:       7.2,
		}
		livingWageId, _ := s.InsertLivingWage(&livingWage)

		Convey("LivingWage should be given an ID", func() {
			So(livingWageId, ShouldBeGreaterThan, 0)

			Convey("LivingWages should contain enough wages", func() {
				wagesForId, _ := s.ListLivingWagesForLocation(livingWageLocation.ID)
				So(len(wagesForId), ShouldBeGreaterThan, 0)

				wages, _ := s.ListLivingWages()
				So(len(wages), ShouldBeGreaterThan, 0)
			})
		})
	})
}

func getStandingOrderFromStandingOrders(standingOrders []StandingOrder, id uint) *StandingOrder {
	for _, standingOrder := range standingOrders {
		if standingOrder.ID == id {
			return &standingOrder
		}
	}
	return nil
}

func EnsureSingleStandingOrderForTestUsers() (*User, StandingOrder, uint) {
	user1 := ensureTestUserExists("user1@example.com")
	s.db.Unscoped().Where("from_user_id=?", user1.ID).Delete(StandingOrder{})
	s.db.Unscoped().Where("to_user_id=?", user1.ID).Delete(StandingOrder{})
	user2 := ensureTestUserExists("user2@example.com")
	s.db.Unscoped().Where("from_user_id=?", user2.ID).Delete(StandingOrder{})
	s.db.Unscoped().Where("to_user_id=?", user2.ID).Delete(StandingOrder{})
	standingOrder := StandingOrder{
		StartDate:   PosixDateTime(time.Now().UTC()),
		FromUserId:  user1.ID,
		ToUserId:    user2.ID,
		Seconds:     1 * 60 * 60,
		TxFee:       1,
		Multiplier:  1,
		Description: "Test StandingOrderS1",
		Status:      TransactionOffered,
		Frequency:   FrequencyMonthly,
	}
	standingOrderId, _ := s.InsertStandingOrder(&standingOrder)
	return user1, standingOrder, standingOrderId
}

func TestStore_StandingOrderCreation(t *testing.T) {
	Convey("Create a standing order", t, func() {
		user1, standingOrder, standingOrderId := EnsureSingleStandingOrderForTestUsers()

		Convey("Standing Order should be created", func() {
			standingOrders, _ := s.ListStandingOrdersForUser(user1.ID)
			standingOrderFromStandingOrders := getStandingOrderFromStandingOrders(standingOrders, standingOrder.ID)
			So(standingOrderFromStandingOrders.ID, ShouldEqual, standingOrderId)

			Convey("Updating the standing order", func() {
				standingOrderFromStandingOrders.Status = TransactionOfferApproved
				standingOrderId2, _ := s.UpdateStandingOrder(standingOrderFromStandingOrders)
				Convey("Concept should keep the same ID and content", func() {
					So(standingOrderId2, ShouldEqual, standingOrderId)
					reloadedStandingOrder, _ := s.LoadStandingOrder(standingOrderId2)
					So(reloadedStandingOrder.ID, ShouldEqual, standingOrderFromStandingOrders.ID)
					So(reloadedStandingOrder.FromUserId, ShouldEqual, standingOrderFromStandingOrders.FromUserId)
					So(reloadedStandingOrder.ToUserId, ShouldEqual, standingOrderFromStandingOrders.ToUserId)
					So(reloadedStandingOrder.Status, ShouldEqual, standingOrderFromStandingOrders.Status)
					So(reloadedStandingOrder.StartDate, ShouldEqual, standingOrderFromStandingOrders.StartDate)
					So(reloadedStandingOrder.StopDate, ShouldEqual, standingOrderFromStandingOrders.StopDate)
					So(reloadedStandingOrder.Frequency, ShouldEqual, standingOrderFromStandingOrders.Frequency)
					So(reloadedStandingOrder.ProcessedUptoDate, ShouldEqual, standingOrderFromStandingOrders.ProcessedUptoDate)
				})
			})
		})
	})
}

func TestStore_StandingOrderProcessingFreshlyCreated(t *testing.T) {
	Convey("Create a standing order", t, func() {
		_, standingOrder, _ := EnsureSingleStandingOrderForTestUsers()

		Convey("Standing order should not require processing", func() {
			standingOrdersToProcess, _ := s.ListStandingOrdersToProcess()
			standingOrderFromStandingOrders := getStandingOrderFromStandingOrders(standingOrdersToProcess, standingOrder.ID)
			So(standingOrderFromStandingOrders, ShouldEqual, (*StandingOrder)(nil))
		})
	})
}

func TestStore_StandingOrderProcessingReadyToProcess(t *testing.T) {
	Convey("Create a standing order", t, func() {
		_, standingOrder, standingOrderId := EnsureSingleStandingOrderForTestUsers()
		standingOrder.Status = TransactionOfferApproved
		standingOrderId2, _ := s.UpdateStandingOrder(&standingOrder)

		Convey("Standing order should require processing", func() {
			standingOrdersToProcess, _ := s.ListStandingOrdersToProcess()
			standingOrderFromStandingOrders := getStandingOrderFromStandingOrders(standingOrdersToProcess, standingOrder.ID)
			So(standingOrderFromStandingOrders.ID, ShouldEqual, standingOrderId)
			So(standingOrderFromStandingOrders.ID, ShouldEqual, standingOrderId2)
		})
	})
}

func TestStore_StandingOrderProcessingAlreadyProcessed(t *testing.T) {
	Convey("Create a standing order", t, func() {
		_, standingOrder, _ := EnsureSingleStandingOrderForTestUsers()
		standingOrder.Status = TransactionOfferApproved
		standingOrder.ProcessedUptoDate = PosixDateTime((time.Now().Add(time.Hour * 24)).UTC())
		standingOrderId2, _ := s.UpdateStandingOrder(&standingOrder)
		So(standingOrder.ID, ShouldEqual, standingOrderId2)

		Convey("Standing order should not require processing", func() {
			standingOrdersToProcess, _ := s.ListStandingOrdersToProcess()
			standingOrderFromStandingOrders := getStandingOrderFromStandingOrders(standingOrdersToProcess, standingOrder.ID)
			So(standingOrderFromStandingOrders, ShouldEqual, (*StandingOrder)(nil))
		})
	})
}

func TestStore_StandingOrderProcessingAlreadyPassed(t *testing.T) {
	Convey("Create a standing order", t, func() {
		_, standingOrder, standingOrderId := EnsureSingleStandingOrderForTestUsers()
		standingOrder.StartDate = PosixDateTime((time.Now().Add(-time.Hour * 24 * 31)).UTC())
		standingOrder.StopDate = PosixDateTime(time.Now().UTC())
		standingOrder.Status = TransactionOfferApproved
		standingOrderId2, _ := s.UpdateStandingOrder(&standingOrder)
		So(standingOrder.ID, ShouldEqual, standingOrderId2)

		Convey("Standing order should require processing", func() {
			standingOrdersToProcess, _ := s.ListStandingOrdersToProcess()
			standingOrderFromStandingOrders := getStandingOrderFromStandingOrders(standingOrdersToProcess, standingOrder.ID)
			So(standingOrderFromStandingOrders.ID, ShouldEqual, standingOrderId)
			So(standingOrderFromStandingOrders.ID, ShouldEqual, standingOrderId2)
		})
	})
}

func TestStore_StandingOrderProcessingAlreadyPassedAndProcessed(t *testing.T) {
	Convey("Create a standing order", t, func() {
		_, standingOrder, _ := EnsureSingleStandingOrderForTestUsers()
		standingOrder.StartDate = PosixDateTime((time.Now().Add(-time.Hour * 24 * 31)).UTC())
		standingOrder.StopDate = PosixDateTime(time.Now().UTC())
		standingOrder.Status = TransactionOfferApproved
		standingOrder.ProcessedUptoDate = PosixDateTime((time.Now().Add(time.Hour * 24)).UTC())
		standingOrderId2, _ := s.UpdateStandingOrder(&standingOrder)
		So(standingOrder.ID, ShouldEqual, standingOrderId2)

		Convey("Standing order should not require processing", func() {
			standingOrdersToProcess, _ := s.ListStandingOrdersToProcess()
			standingOrderFromStandingOrders := getStandingOrderFromStandingOrders(standingOrdersToProcess, standingOrder.ID)
			So(standingOrderFromStandingOrders, ShouldEqual, (*StandingOrder)(nil))
		})
	})
}

func TestStore_TestDays(t *testing.T) {
	Convey("Create a few dates", t, func() {
		date := time.Date(2026, time.January, 1, 0, 0, 0, 0, time.UTC)
		date1 := PosixDateTime(date)
		date2 := PosixDateTime(date.Add(time.Hour * 24 * 1))
		date3 := PosixDateTime(date.Add(time.Hour * 24 * 31))
		date4 := PosixDateTime(date.Add(time.Hour * 24 * 30 * 12))
		So(date1.Days(), ShouldEqual, 20454)
		So(date2.Days(), ShouldEqual, 20455)
		So(date3.Days(), ShouldEqual, 20485)
		So(date4.Days(), ShouldEqual, 20814)
	})
}
