package store

import (
	"database/sql/driver"
	"errors"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"log"
	"os"
	"strconv"
	"time"
)

type Store struct {
	db *gorm.DB
}

type PublicUser struct {
	gorm.Model
	Email      string `gorm:"unique_index"`
	FirstName  string
	MidNames   string
	LastName   string
	Location   string
	LocationId uint
	PhotoId    uint
}

type PublicUserWithBalance struct {
	PublicUser
	Balance int64
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
	Mobile       string
	Confirmed    bool
	AttemptCount int    `json:"-"`
	LastAttempt  string `json:"-"`
	Locked       string `json:"-"`
	Permissions  UserPermissions
}

type PrivilegedUserWithBalance struct {
	PrivilegedUser
	Balance int64
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
	return []byte(strconv.FormatInt(time.Time(d).UTC().UnixMilli(), 10)), nil
}

func (d *PosixDateTime) UnmarshalJSON(b []byte) (err error) {
	p, err := strconv.ParseInt(string(b), 10, 64)
	if err != nil {
		return
	}
	t := time.UnixMilli(p).UTC()
	*d = PosixDateTime(t)
	return
}

func (d PosixDateTime) Value() (driver.Value, error) {
	return time.Time(d).UTC(), nil
}

func (d *PosixDateTime) Scan(src interface{}) error {
	if val, ok := src.(time.Time); ok {
		*d = PosixDateTime(val)
	}
	return nil
}

func (d PosixDateTime) AddDate(years int, months int, days int) PosixDateTime {
	return PosixDateTime(time.Time(d).AddDate(years, months, days))
}

func (d PosixDateTime) Days() uint64 {
	unixSeconds := time.Time(d).UTC().Unix()
	secondsPerMinute := 60
	secondsPerHour := 60 * secondsPerMinute
	secondsPerDay := 24 * secondsPerHour
	return uint64(unixSeconds) / uint64(secondsPerDay)
}

func (d PosixDateTime) DateString() string {
	return time.Time(d).Format("2006-01-02")
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
	LocationId      uint
	StandingOrderId uint
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
	postgresArgs, err := os.ReadFile(postgresArgsFileName)
	if err != nil {
		postgresArgs, err = os.ReadFile("../" + postgresArgsFileName)
		if err != nil {
			postgresArgs = []byte("host=myhost port=myport sslmode=disable user=myusername dbname=mydbname password=mypassword")
			err = os.WriteFile(postgresArgsFileName, postgresArgs, 0666)
			if err != nil {
				log.Fatal(err)
			}
		}
	}
	return string(postgresArgs)
}

func (s *Store) StoreInit() {
	pg := postgres.Open(readPostgresArgs())
	db, err := gorm.Open(pg, &gorm.Config{
		// DEBUG - add/remove to investigate SQL queries being executed
		// Logger: logger.Default.LogMode(logger.Info),
	})

	if err != nil {
		log.Fatal(err)
	}
	s.db = db

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatal(err)
	}
	sqlDB.Exec("CREATE EXTENSION postgis;")
	sqlDB.Exec("SET TIME ZONE 'UTC';")

	err = db.AutoMigrate(&User{}, &Concept{}, &ConceptTag{}, &Transaction{}, &LivingWageLocation{}, &LivingWage{}, &StandingOrder{})
	if err != nil {
		log.Fatal(err)
	}

	// We already have these created in our database from the old gorm code where they existed
	// The new model of linking directly to an instance of the Object involves lots of extra
	// database loading so we have rejected upgrading to that, suspect custom Exec lines will
	// be required for any new foreign keys need.
	// 	db.Model(&ConceptTag{}).AddForeignKey("concept_id", "concepts(id)", "CASCADE", "RESTRICT")
	// 	db.Model(&Transaction{}).AddForeignKey("from_user_id", "users(id)", "CASCADE", "RESTRICT")
	// 	db.Model(&Transaction{}).AddForeignKey("to_user_id", "users(id)", "CASCADE", "RESTRICT")
	// 	db.Model(&LivingWage{}).AddForeignKey("location_id", "living_wage_locations(id)", "CASCADE", "RESTRICT")
	// 	db.Model(&StandingOrder{}).AddForeignKey("from_user_id", "users(id)", "CASCADE", "RESTRICT")
	// 	db.Model(&StandingOrder{}).AddForeignKey("to_user_id", "users(id)", "CASCADE", "RESTRICT")
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
	err := s.db.Where("email=?", email).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, err
}

func (s *Store) PurgeUser(email string) {
	user := User{}
	err := s.db.Where("email=?", email).First(&user).Error
	if err != nil {
		s.db.Unscoped().Where("from_user_id=? OR to_user_id=?", user.ID, user.ID).Delete(Transaction{})
	}
	s.db.Unscoped().Where("email=?", email).Delete(User{})
}

func (s *Store) LoadPublicUser(id uint) (*PublicUser, error) {
	user := User{}
	err := s.db.Where("id=?", id).First(&user).Error
	if err != nil {
		return nil, err
	}
	publicUser := PublicUser{}
	publicUser.ID = user.ID
	publicUser.FirstName = user.FirstName
	publicUser.MidNames = user.MidNames
	publicUser.LastName = user.LastName
	publicUser.Location = user.Location
	publicUser.LocationId = user.LocationId
	publicUser.PhotoId = user.PhotoId
	return &publicUser, err
}

func (s *Store) LoadPrivilegedUserAsSelf(userId uint, loggedInUserId uint) (*PrivilegedUser, error) {
	if userId != loggedInUserId {
		return nil, errors.New("cannot load others users")
	}
	user := PrivilegedUser{}
	err := s.db.Where("id=?", userId).First(&user).Error
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
	err := s.db.Where("id=?", userId).First(&user).Error
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

func (s *Store) PurgeConcept(name string) {
	s.db.Unscoped().Where("name=?", name).Delete(Concept{})
}

func (s *Store) LoadConcept(id uint) (*Concept, error) {
	concept := Concept{}
	err := s.db.Where("id=?", id).First(&concept).Error
	return &concept, err
}

func (s *Store) FindConcept(name string) (*Concept, error) {
	concept := Concept{}
	err := s.db.Where("name=?", name).First(&concept).Error
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
	err := s.db.Where("concept_id=?", concept.ID).Order("concept_tags.order").Find(&conceptTags).Error
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
	err := s.db.Where("tag=?", tag).First(&conceptTag).Error
	if err != nil {
		return nil, err
	}
	return &conceptTag, err
}

func (s *Store) ConceptTagsForConceptId(conceptId uint) ([]ConceptTag, error) {
	var conceptTags []ConceptTag
	err := s.db.Where("concept_id=?", conceptId).Order("concept_tags.order").Find(&conceptTags).Error
	return conceptTags, err
}

func (s *Store) ListConceptTags() ([]ConceptTag, error) {
	var conceptTags []ConceptTag
	err := s.db.Order("concept_tags.order").Find(&conceptTags).Error
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

func (s *Store) LastTransactionForStandingOrder(standingOrderId uint) (Transaction, error) {
	var transaction Transaction
	err := s.db.Where("standing_order_id=?", standingOrderId).Order("initiated_date").Last(&transaction).Error
	return transaction, err
}

func (s *Store) PurgeTransaction(transaction Transaction) {
	s.db.Unscoped().Where("id=?", transaction.ID).Delete(Transaction{})
}

func (s *Store) LoadTransaction(id uint) (*Transaction, error) {
	transaction := Transaction{}
	err := s.db.Where("id=?", id).First(&transaction).Error
	return &transaction, err
}

func (s *Store) UpdateTransaction(transaction *Transaction) (uint, error) {
	if transaction.Multiplier < 1 || transaction.Multiplier > 3 {
		return 0, nil
	}
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

type LivingWageLocation struct {
	gorm.Model
	Name   string
	Symbol string
}

func (s *Store) PurgeLivingWageLocation(name string) {
	s.db.Unscoped().Where("name=?", name).Delete(LivingWageLocation{})
}

func (s *Store) InsertLivingWageLocation(livingWageLocation *LivingWageLocation) (uint, error) {
	err := s.db.Create(livingWageLocation).Error
	return livingWageLocation.ID, err
}

func (s *Store) UpdateLivingWageLocation(livingWageLocation *LivingWageLocation) (uint, error) {
	err := s.db.Save(livingWageLocation).Error
	return livingWageLocation.ID, err
}

func (s *Store) FindLivingWageLocation(name string) (*LivingWageLocation, error) {
	location := LivingWageLocation{}
	err := s.db.Where("name=?", name).First(&location).Error
	if err != nil {
		return nil, err
	}
	return &location, err
}

func (s *Store) LoadLivingWageLocation(id uint) (*LivingWageLocation, error) {
	livingWageLocation := LivingWageLocation{}
	err := s.db.Where("id=?", id).First(&livingWageLocation).Error
	return &livingWageLocation, err
}

func (s *Store) ListLivingWageLocations() ([]LivingWageLocation, error) {
	var livingWageLocation []LivingWageLocation
	err := s.db.Limit(200).Order("name").Find(&livingWageLocation).Error
	if err != nil {
		return nil, err
	}
	return livingWageLocation, err
}

type LivingWage struct {
	gorm.Model
	StartDate  PosixDateTime `gorm:"type:timestamp with time zone"`
	StopDate   PosixDateTime `gorm:"type:timestamp with time zone"`
	Wage       float32
	LocationId uint
}

func (s *Store) InsertLivingWage(livingWage *LivingWage) (uint, error) {
	err := s.db.Create(livingWage).Error
	return livingWage.ID, err
}

func (s *Store) ListLivingWages() ([]LivingWage, error) {
	var livingWage []LivingWage
	err := s.db.Limit(200).Order("start_date").Find(&livingWage).Error
	if err != nil {
		return nil, err
	}
	return livingWage, err
}

func (s *Store) LoadLivingWage(id uint) (*LivingWage, error) {
	livingWage := LivingWage{}
	err := s.db.Where("id=?", id).First(&livingWage).Error
	return &livingWage, err
}

func (s *Store) UpdateLivingWage(livingWage *LivingWage) (uint, error) {
	err := s.db.Save(livingWage).Error
	return livingWage.ID, err
}

func (s *Store) ListLivingWagesForLocation(locationId uint) ([]LivingWage, error) {
	var livingWage []LivingWage
	err := s.db.Where("location_id=?", locationId).Limit(200).Order("start_date").Find(&livingWage).Error
	if err != nil {
		return nil, err
	}
	return livingWage, err
}

func (s *Store) FindLivingWage(locationId uint, startDate PosixDateTime, stopDate PosixDateTime) (*LivingWage, error) {
	livingWage := LivingWage{}
	err := s.db.Where("location_id=? AND start_date=? AND stop_date=?", locationId, startDate, stopDate).First(&livingWage).Error
	if err != nil {
		return nil, err
	}
	return &livingWage, err
}

func (s *Store) PurgeLivingWage(livingWage *LivingWage) {
	s.db.Unscoped().Where("id=?", livingWage.ID).Delete(LivingWage{})
}

const (
	FrequencyUnknown = iota
	FrequencyDaily
	FrequencyWeekly
	FrequencyMonthly
	FrequencyAnnually
)

type StandingOrder struct {
	gorm.Model
	StartDate         PosixDateTime `gorm:"type:timestamp with time zone"`
	StopDate          PosixDateTime `gorm:"type:timestamp with time zone"`
	ConfirmedDate     PosixDateTime `gorm:"type:timestamp with time zone"`
	ProcessedUptoDate PosixDateTime `gorm:"type:timestamp with time zone"`
	FromUserId        uint
	ToUserId          uint
	Seconds           uint64 `gorm:"type:bigint"`
	Multiplier        float32
	TxFee             uint
	Description       string
	LocationId        uint
	Status            uint
	Frequency         uint
}

func (s *Store) InsertStandingOrder(standingOrder *StandingOrder) (uint, error) {
	if standingOrder.Multiplier < 1 || standingOrder.Multiplier > 3 {
		return 0, nil
	}
	err := s.db.Create(standingOrder).Error
	return standingOrder.ID, err
}

func (s *Store) ListStandingOrdersForUser(userId uint) ([]StandingOrder, error) {
	var standingOrders []StandingOrder
	err := s.db.Where("from_user_id=? OR to_user_id=?", userId, userId).Order("start_date, stop_date").Find(&standingOrders).Error
	return standingOrders, err
}

func (s *Store) ListStandingOrdersToProcess() ([]StandingOrder, error) {
	var standingOrders []StandingOrder
	now := PosixDateTime(time.Now().UTC())
	err := s.db.Where("status > 2 AND (stop_date<start_date OR ? < stop_date OR processed_upto_date<=?) AND processed_upto_date<=?", now, now, now).Order("processed_upto_date").Find(&standingOrders).Error
	return standingOrders, err
}

func (s *Store) PurgeStandingOrder(standingOrder StandingOrder) {
	s.db.Unscoped().Where("id=?", standingOrder.ID).Delete(StandingOrder{})
}

func (s *Store) LoadStandingOrder(id uint) (*StandingOrder, error) {
	standingOrder := StandingOrder{}
	err := s.db.Where("id=?", id).First(&standingOrder).Error
	return &standingOrder, err
}

func (s *Store) UpdateStandingOrder(standingOrder *StandingOrder) (uint, error) {
	if standingOrder.Multiplier < 1 || standingOrder.Multiplier > 3 {
		return 0, nil
	}
	err := s.db.Save(standingOrder).Error
	return standingOrder.ID, err
}

func (s *Store) DeleteStandingOrder(id uint) error {
	err := s.db.Unscoped().Where("id=?", id).Delete(StandingOrder{}).Error
	return err
}
