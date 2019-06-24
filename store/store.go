package store

import (
	"errors"
	"github.com/adamboardman/gorm"
	_ "github.com/adamboardman/gorm/dialects/postgres"
	"io/ioutil"
	"log"
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

func (PublicUser) TableName() string {
	return "users"
}

type User struct {
	PublicUser
	Email              string `gorm:"unique_index"`
	Mobile             string
	Salt               string `json:"-"`
	Password           string `json:"-"`
	ConfirmVerifier    string `json:"-"`
	Confirmed          bool
	AttemptCount       int    `json:"-"`
	LastAttempt        string `json:"-"`
	Locked             string `json:"-"`
	RecoverVerifier    string `json:"-"`
	RecoverTokenExpiry string `json:"-"`
}

type Concept struct {
	gorm.Model
	Name    string
	Summary string
	Full    string
}

type ConceptAltName struct {
	gorm.Model
	ConceptId uint
	AltName   string
	Order     uint
}

func readPostgresArgs() string {
	const postgresArgsFileName = "postgres_args.txt"
	postgresArgs, err := ioutil.ReadFile(postgresArgsFileName)
	if err != nil {
		postgresArgs, err = ioutil.ReadFile("../" + postgresArgsFileName)
		if err != nil {
			postgresArgs = []byte("host=myhost port=myport sslmode=disable user=conceptualiser dbname=concepts password=mypassword")
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

	db.DB().Exec("CREATE EXTENSION postgis;")

	err = db.AutoMigrate(&User{}, &Concept{}, &ConceptTag{}).Error
	if err != nil {
		log.Fatal(err)
	}

	//DEBUG - add/remove to investigate SQL queries being executed
	db.LogMode(true)

	db.Model(&ConceptAltName{}).AddForeignKey("concept_id", "concepts(id)", "CASCADE", "RESTRICT")
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

func (s *Store) LoadUserAsSelf(userId uint, loggedInUserId uint) (interface{}, error) {
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

func (s *Store) FindConcept(email string) (*Concept, error) {
	concept := Concept{}
	err := s.db.Where("name=?", email).Find(&concept).Error
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

func (s *Store) InsertConceptAltName(conceptAltName *ConceptAltName) (uint, error) {
	err := s.db.Create(conceptAltName).Error
	return conceptAltName.ID, err
}

func (s *Store) UpdateConceptAltName(conceptAltName *ConceptAltName) (uint, error) {
	err := s.db.Save(conceptAltName).Error
	return conceptAltName.ID, err
}

func (s *Store) ConceptAltNames(concept *Concept) ([]string, error) {
	var names []string
	var altNames []ConceptAltName
	err := s.db.Where("concept_id=?", concept.ID).Limit(200).Order("order").Find(&altNames).Error
	if err == nil {
		names = append(names, concept.Name)
		for _, altName := range altNames {
			names = append(names, altName.AltName)
		}
		return names, err
	}
	return nil, err
}
