module Types exposing (ApiActionResponse, Concept, LoginForm, Model, Msg(..), Page(..), Problem(..), ProfileForm, RegisterForm, Session, Tag, Transaction, TransactionForm, TransactionType(..), User, ValidatedField(..), authHeader, conceptDecoder, formatDate, indexUser, posixTime, profileDecoder, tagDecoder, tgsFromTimeAndMultiplier, tgsLocale, timeFromTgs, toIntMonth, transactionDecoder, userDecoder)

import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (Locale)
import Http
import Json.Decode as Decode exposing (Decoder, at, float, int, list, map3, map4, map5, map6, map7, map8, string)
import Json.Decode.Pipeline exposing (optional, required)
import Loading
import Time exposing (Month)
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
    , timeZone : Time.Zone
    , time : Time.Posix
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
    , date : Time.Posix
    , fromUserId : Int
    , toUserId : Int
    , seconds : Int
    , multiplier : Float
    , txFee : Int
    , status : Int
    , description : String
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
    , tgs : String
    , time : String
    , multiplier : String
    , description : String
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
    | EnteredTransactionTGs String
    | EnteredTransactionTime String
    | EnteredTransactionMultiplier String
    | EnteredTransactionDescription String
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
    | AdjustTimeZone Time.Zone
    | TimeTick Time.Posix



-- FORMATTERS AND LOCALS


tgsLocale : Locale
tgsLocale =
    Locale 3 "," "." "−" "" "" ""


toIntMonth : Month -> Int
toIntMonth month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


formatDate : Model -> Time.Posix -> String
formatDate model date =
    let
        year =
            String.fromInt (Time.toYear model.timeZone date)

        month =
            String.padLeft 2 '0' (String.fromInt (toIntMonth (Time.toMonth model.timeZone date)))

        day =
            String.padLeft 2 '0' (String.fromInt (Time.toDay model.timeZone date))

        hour =
            String.padLeft 2 '0' (String.fromInt (Time.toHour model.timeZone date))

        minute =
            String.padLeft 2 '0' (String.fromInt (Time.toMinute model.timeZone date))
    in
    year ++ "-" ++ month ++ "-" ++ day ++ " " ++ hour ++ ":" ++ minute


tgsFromTimeAndMultiplier : String -> String -> String
tgsFromTimeAndMultiplier time multiplier =
    let
        timeParts =
            String.split ":" time

        seconds =
            (Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (List.head timeParts))) * 60 * 60)
                + (Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (List.head (Maybe.withDefault [] (List.tail timeParts))))) * 60)

        multiplied =
            toFloat seconds * Maybe.withDefault 1.0 (String.toFloat multiplier)
    in
    format tgsLocale (multiplied / (60.0 * 60.0))


timeFromTgs : String -> String -> String
timeFromTgs tgs multiplier =
    let
        divider =
            Maybe.withDefault 1 (String.toFloat multiplier)

        tgsFloat =
            Maybe.withDefault 0 (String.toFloat tgs)

        divided =
            tgsFloat / divider

        tgsInt =
            floor divided
    in
    String.padLeft 2 '0' (String.fromInt tgsInt) ++ ":" ++ String.padLeft 2 '0' (String.fromInt (floor ((divided - toFloat tgsInt) * 60.0)))



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


posixTime : Decode.Decoder Time.Posix
posixTime =
    Decode.int
        |> Decode.andThen
            (\ms -> Decode.succeed <| Time.millisToPosix ms)


transactionDecoder : Decoder Transaction
transactionDecoder =
    Decode.succeed Transaction
        |> required "ID" int
        |> required "Date" posixTime
        |> required "FromUserId" int
        |> required "ToUserId" int
        |> required "Seconds" int
        |> required "Multiplier" float
        |> required "TxFee" int
        |> required "Status" int
        |> required "Description" string



-- AUTH HEADER


authHeader : String -> Http.Header
authHeader token =
    Http.header "authorization" ("Bearer " ++ token)
