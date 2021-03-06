package store

import (
	"database/sql/driver"
	"errors"
	"github.com/adamboardman/gorm"
	_ "github.com/adamboardman/gorm/dialects/postgres"
	"io/ioutil"
	"log"
	"strconv"
	"time"
)

type Store struct {
	db *gorm.DB
}

type PublicUser struct {
	gorm.Model
	FirstName string
	MidNames  string
	LastName  string
	Location  string
	PhotoID   uint
}

type PublicUserWithBalance struct {
	PublicUser
	Balance   int64
}

func (PublicUser) TableName() string {
	return "users"
}

type UserPermissions int

const (
	UserPermissionsUser UserPermissions = iota + 1
	UserPermissionsEditor
	UserPermissionsAdmin
)

type User struct {
	PrivilegedUser
	Salt               string `json:"-"`
	Password           string `json:"-"`
	ConfirmVerifier    string `json:"-"`
	RecoverVerifier    string `json:"-"`
	RecoverTokenExpiry string `json:"-"`
}

type PrivilegedUser struct {
	PublicUser
	Email              string `gorm:"unique_index"`
	Mobile             string
	Confirmed          bool
	AttemptCount       int    `json:"-"`
	LastAttempt        string `json:"-"`
	Locked             string `json:"-"`
	Permissions        UserPermissions
}

type PrivilegedUserWithBalance struct {
	PrivilegedUser
	Balance   int64
}

type Concept struct {
	gorm.Model
	Name    string
	Summary string
	Full    string
}

type ConceptTag struct {
	gorm.Model
	Tag       string
	ConceptId uint
	Order     uint
}

const (
	TransactionUnknown = iota
	TransactionOffered
	TransactionRequested
	TransactionOfferApproved
	TransactionRequestApproved
	TransactionOfferRejected
	TransactionRequestRejected
)

type PosixDateTime time.Time

func (d PosixDateTime) MarshalJSON() ([]byte, error) {
	if time.Time(d).IsZero() {
		return []byte("0"), nil
	}
	return []byte(strconv.FormatInt(time.Time(d).Unix(), 10)), nil
}

func (d *PosixDateTime) UnmarshalJSON(b []byte) (err error) {
	p, err := strconv.ParseInt(string(b), 10, 64);
	if err != nil {
		return
	}
	t := time.Unix(p, 0)
	*d = PosixDateTime(t)
	return
}

func (d PosixDateTime) Value() (driver.Value, error) {
	return time.Time(d), nil
}

func (d *PosixDateTime) Scan(src interface{}) error {
	if val, ok := src.(time.Time); ok {
		*d = PosixDateTime(val)
	}
	return nil
}

type Transaction struct {
	gorm.Model
	InitiatedDate   PosixDateTime `gorm:"type:timestamp with time zone"`
	ConfirmedDate   PosixDateTime `gorm:"type:timestamp with time zone"`
	FromUserId      uint
	ToUserId        uint
	Seconds         uint64 `gorm:"type:bigint"`
	Multiplier      float32
	TxFee           uint
	Description     string
	Location        string
	ToPreviousTId   uint
	FromPreviousTId uint
	Status          uint
	FromUserBalance int64 `gorm:"type:bigint"`
	ToUserBalance   int64 `gorm:"type:bigint"`
}

func (t Transaction) Balance(userId uint) int64 {
	if userId == t.FromUserId {
		return t.FromUserBalance
	} else {
		return t.ToUserBalance
	}
}

func readPostgresArgs() string {
	const postgresArgsFileName = "postgres_args.txt"
	postgresArgs, err := ioutil.ReadFile(postgresArgsFileName)
	if err != nil {
		postgresArgs, err = ioutil.ReadFile("../" + postgresArgsFileName)
		if err != nil {
			postgresArgs = []byte("host=myhost port=myport sslmode=disable user=thinkglobally dbname=concepts password=mypassword")
			err = ioutil.WriteFile(postgresArgsFileName, postgresArgs, 0666)
			if err != nil {
				log.Fatal(err)
			}
		}
	}
	return string(postgresArgs)
}

func (s *Store) StoreInit(dbName string) {
	db, err := gorm.Open("postgres", readPostgresArgs())

	if err != nil {
		log.Fatal(err)
	}
	s.db = db

	_, _ = db.DB().Exec("CREATE EXTENSION postgis;")

	err = db.AutoMigrate(&User{}, &Concept{}, &ConceptTag{}, &Transaction{}).Error
	if err != nil {
		log.Fatal(err)
	}

	//DEBUG - add/remove to investigate SQL queries being executed
	//db.LogMode(true)

	db.Model(&ConceptTag{}).AddForeignKey("concept_id", "concepts(id)", "CASCADE", "RESTRICT")
	db.Model(&Transaction{}).AddForeignKey("from_user_id", "users(id)", "CASCADE", "RESTRICT")
	db.Model(&Transaction{}).AddForeignKey("to_user_id", "users(id)", "CASCADE", "RESTRICT")
}

func (s *Store) InsertUser(user *User) (uint, error) {
	err := s.db.Create(user).Error
	return user.ID, err
}

func (s *Store) UpdateUser(user *User) (uint, error) {
	err := s.db.Save(user).Error
	return user.ID, err
}

func (s *Store) FindUser(email string) (*User, error) {
	user := User{}
	err := s.db.Where("email=?", email).Find(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) PurgeUser(email string) {
	user := User{}
	err := s.db.Where("email=?", email).Find(&user).Error
	if err != nil {
		s.db.Unscoped().Where("from_user_id=? OR to_user_id=?",user.ID,user.ID).Delete(Transaction{})
	}
	s.db.Unscoped().Where("email=?", email).Delete(User{})
}

func (s *Store) LoadPublicUser(id uint) (*PublicUser, error) {
	user := User{}
	err := s.db.Where("id=?", id).Find(&user).Error
	if err != nil {
		return nil, err
	}
	publicUser := PublicUser{}
	publicUser.ID = user.ID
	publicUser.FirstName = user.FirstName
	publicUser.MidNames = user.MidNames
	publicUser.LastName = user.LastName
	publicUser.Location = user.Location
	publicUser.PhotoID = user.PhotoID
	return &publicUser, err
}

func (s *Store) LoadPrivilegedUserAsSelf(userId uint, loggedInUserId uint) (*PrivilegedUser, error) {
	if userId != loggedInUserId {
		return nil, errors.New("cannot load others users")
	}
	user := PrivilegedUser{}
	err := s.db.Where("id=?", userId).Find(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) LoadUserAsSelf(userId uint, loggedInUserId uint) (*User, error) {
	if userId != loggedInUserId {
		return nil, errors.New("cannot load others users")
	}
	user := User{}
	err := s.db.Where("id=?", userId).Find(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) InsertConcept(concept *Concept) (uint, error) {
	err := s.db.Create(concept).Error
	return concept.ID, err
}

func (s *Store) UpdateConcept(concept *Concept) (uint, error) {
	err := s.db.Save(concept).Error
	return concept.ID, err
}

func (s *Store) PurgeConcept(email string) {
	s.db.Unscoped().Where("name=?", email).Delete(Concept{})
}

func (s *Store) LoadConcept(id uint) (*Concept, error) {
	concept := Concept{}
	err := s.db.Where("id=?", id).Find(&concept).Error
	return &concept, err
}

func (s *Store) FindConcept(name string) (*Concept, error) {
	concept := Concept{}
	err := s.db.Where("name=?", name).Find(&concept).Error
	if err != nil {
		return nil, err
	}
	return &concept, err
}

func (s *Store) ListConcepts() ([]Concept, error) {
	var concepts []Concept
	err := s.db.Limit(200).Order("name").Find(&concepts).Error
	if err != nil {
		return nil, err
	}
	return concepts, err
}

func (s *Store) InsertConceptTag(conceptTag *ConceptTag) (uint, error) {
	err := s.db.Create(conceptTag).Error
	return conceptTag.ID, err
}

func (s *Store) UpdateConceptTag(conceptTag *ConceptTag) (uint, error) {
	err := s.db.Save(conceptTag).Error
	return conceptTag.ID, err
}

func (s *Store) ConceptTagsAsStrings(concept *Concept) ([]string, error) {
	var names []string
	var conceptTags []ConceptTag
	err := s.db.Where("concept_id=?", concept.ID).Order("order").Find(&conceptTags).Error
	if err == nil {
		for _, conceptTag := range conceptTags {
			names = append(names, conceptTag.Tag)
		}
		return names, err
	}
	return nil, err
}

func (s *Store) FindConceptTag(tag string) (*ConceptTag, error) {
	conceptTag := ConceptTag{}
	err := s.db.Where("tag=?", tag).Find(&conceptTag).Error
	if err != nil {
		return nil, err
	}
	return &conceptTag, err
}

func (s *Store) ConceptTagsForConceptId(conceptId uint) ([]ConceptTag, error) {
	var conceptTags []ConceptTag
	err := s.db.Where("concept_id=?", conceptId).Order("order").Find(&conceptTags).Error
	return conceptTags, err
}

func (s *Store) ListConceptTags() ([]ConceptTag, error) {
	var conceptTags []ConceptTag
	err := s.db.Order("order").Find(&conceptTags).Error
	return conceptTags, err
}

func (s *Store) DeleteConceptTag(id uint) error {
	err := s.db.Unscoped().Where("id=?", id).Delete(ConceptTag{}).Error
	return err
}

func (s *Store) PurgeConceptTag(tag string) {
	s.db.Unscoped().Where("tag=?", tag).Delete(ConceptTag{})
}

func (s *Store) InsertTransaction(transaction *Transaction) (uint, error) {
	if transaction.Multiplier < 1 || transaction.Multiplier > 3 {
		return 0, nil
	}
	err := s.db.Create(transaction).Error
	return transaction.ID, err
}

func (s *Store) ListTransactionsForUser(userId uint) ([]Transaction, error) {
	var transactions []Transaction
	err := s.db.Where("from_user_id=? OR to_user_id=?", userId, userId).Order("confirmed_date,initiated_date").Find(&transactions).Error
	return transactions, err
}

func (s *Store) PurgeTransaction(transaction Transaction) {
	s.db.Unscoped().Where("id=?", transaction.ID).Delete(Transaction{})
}

func (s *Store) LoadTransaction(id uint) (*Transaction, error) {
	transaction := Transaction{}
	err := s.db.Where("id=?", id).Find(&transaction).Error
	return &transaction, err
}

func (s *Store) UpdateTransaction(transaction *Transaction) (uint, error) {
	err := s.db.Save(transaction).Error
	return transaction.ID, err
}

func (s *Store) ListTransactionPartners(userId uint) ([]PublicUser, error) {
	var users []PublicUser
	err := s.db.Raw("SELECT * FROM users WHERE users.deleted_at IS NULL AND users.id IN (SELECT to_user_id AS user_id FROM transactions WHERE transactions.deleted_at IS NULL AND ((from_user_id=? OR to_user_id=?)) UNION SELECT from_user_id AS user_id FROM transactions WHERE transactions.deleted_at IS NULL AND ((from_user_id=? OR to_user_id=?))) ORDER BY users.id", userId, userId, userId, userId).Scan(&users).Error
	return users, err
}

func (s *Store) LastConfirmedTransactionForUser(userId uint) (Transaction, error) {
	var transaction Transaction
	err := s.db.Where("status > 2 AND (from_user_id=? OR to_user_id=?)", userId, userId).Order("confirmed_date DESC").Take(&transaction).Error
	return transaction, err

}
