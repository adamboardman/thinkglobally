module Types exposing (ApiActionResponse, Concept, LoginForm, Model, Msg(..), Page(..), Problem(..), ProfileForm, RegisterForm, Session, Tag, Transaction, TransactionForm, TransactionType(..), User, ValidatedField(..), authHeader, conceptDecoder, indexUser, profileDecoder, tagDecoder, tgsLocale, transactionDecoder, userDecoder)

import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import FormatNumber.Locales exposing (Locale)
import Http
import Json.Decode as Decode exposing (Decoder, at, float, int, list, map3, map4, map5, map6, map7, map8, string)
import Json.Decode.Pipeline exposing (optional, required)
import Loading
import Url exposing (Url)


type alias Model =
    { navKey : Nav.Key
    , page : Page
    , navState : Navbar.State
    , loading : Loading.LoadingState
    , modalVisibility : Modal.Visibility
    , problems : List Problem
    , loginForm : LoginForm
    , registerForm : RegisterForm
    , profileForm : ProfileForm
    , transactionForm : TransactionForm
    , session : Session
    , apiActionResponse : ApiActionResponse
    , loggedInUser : User
    , concept : Concept
    , creatingTransaction : TransactionType
    , transactions : List Transaction
    , pendingTransactions : List Transaction
    , txUsers : Dict String User
    }


type Page
    = Home
    | Login
    | Logout
    | Register
    | Profile
    | Transactions
    | NotFound


type alias Session =
    { loginExpire : String
    , loginToken : String
    }


type alias ApiActionResponse =
    { status : Int
    , resourceId : Int
    }


type alias User =
    { id : Int
    , firstName : String
    , midNames : String
    , lastName : String
    , location : String
    , email : String
    , mobile : String
    , permissions : Int
    }


type alias Concept =
    { id : Int
    , name : String
    , summary : String
    , full : String
    , tags : List Tag
    }


type alias Tag =
    { id : Int
    , order : Int
    , tag : String
    }


type alias Transaction =
    { id : Int
    , fromUserId : Int
    , toUserId : Int
    , seconds : Int
    , multiplier : Float
    , txFee : Int
    , status : Int
    }


type alias LoginForm =
    { email : String
    , password : String
    }


type alias RegisterForm =
    { email : String
    , password : String
    , password_confirm : String
    }


type alias ProfileForm =
    { id : Int
    , firstName : String
    , midNames : String
    , lastName : String
    , location : String
    , email : String
    , mobile : String
    }


type alias TransactionForm =
    { email : String
    , time : String
    , multiplier : String
    }


type ValidatedField
    = Email
    | Password
    | ConfirmPassword
    | FirstName
    | MidNames
    | LastName
    | Location
    | Mobile
    | Time
    | Multiplier


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type TransactionType
    = TxNone
    | TxOffer
    | TxRequest


type Msg
    = ChangedUrl Url
    | ClickedLink UrlRequest
    | NavMsg Navbar.State
    | CloseModal
    | ShowModal
    | SubmittedLoginForm
    | SubmittedRegisterForm
    | SubmittedProfileForm
    | SubmittedTransactionForm
    | EnteredLoginEmail String
    | EnteredLoginPassword String
    | EnteredRegisterEmail String
    | EnteredRegisterPassword String
    | EnteredRegisterConfirmPassword String
    | EnteredUserFirstName String
    | EnteredUserMidNames String
    | EnteredUserLastName String
    | EnteredUserLocation String
    | EnteredUserMobile String
    | EnteredUserEmail String
    | EnteredTransactionEmail String
    | EnteredTransactionTime String
    | EnteredTransactionMultiplier String
    | CompletedLogin (Result Http.Error Session)
    | GotRegisterJson (Result Http.Error ApiActionResponse)
    | LoadedUser (Result Http.Error User)
    | LoadedProfile (Result Http.Error ProfileForm)
    | LoadedConcept (Result Http.Error Concept)
    | GotUpdateProfileJson (Result Http.Error ApiActionResponse)
    | TransactionState TransactionType
    | AddedTransaction (Result Http.Error ApiActionResponse)
    | LoadedTransactions (Result Http.Error (List Transaction))
    | LoadedTxUsers (Result Http.Error (List User))
    | AcceptedTransaction (Result Http.Error ApiActionResponse)
    | RejectedTransaction (Result Http.Error ApiActionResponse)
    | AcceptTransaction Int
    | RejectTransaction Int


tgsLocale : Locale
tgsLocale =
    Locale 3 "," "." "−" "" "" ""



-- INDEXERS


indexUser : User -> ( String, User )
indexUser user =
    ( String.fromInt user.id, user )



-- DECODERS


userDecoder : Decoder User
userDecoder =
    Decode.succeed User
        |> required "ID" int
        |> required "FirstName" string
        |> required "MidNames" string
        |> required "LastName" string
        |> optional "Location" string ""
        |> optional "Email" string ""
        |> optional "Mobile" string ""
        |> optional "Permissions" int 0


profileDecoder : Decoder ProfileForm
profileDecoder =
    map7 ProfileForm
        (at [ "ID" ] int)
        (at [ "FirstName" ] string)
        (at [ "MidNames" ] string)
        (at [ "LastName" ] string)
        (at [ "Location" ] string)
        (at [ "Email" ] string)
        (at [ "Mobile" ] string)


conceptDecoder : Decoder Concept
conceptDecoder =
    Decode.succeed Concept
        |> required "ID" int
        |> required "Name" string
        |> required "Summary" string
        |> required "Full" string
        |> optional "Tags" (list tagDecoder) []


tagDecoder : Decoder Tag
tagDecoder =
    Decode.succeed Tag
        |> required "ID" int
        |> required "Order" int
        |> required "Tag" string


transactionDecoder : Decoder Transaction
transactionDecoder =
    Decode.succeed Transaction
        |> required "ID" int
        |> required "FromUserId" int
        |> required "ToUserId" int
        |> required "Seconds" int
        |> required "Multiplier" float
        |> required "TxFee" int
        |> required "Status" int



-- AUTH HEADER


authHeader : String -> Http.Header
authHeader token =
    Http.header "authorization" ("Bearer " ++ token)
