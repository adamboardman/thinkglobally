module Types exposing (ApiActionResponse, Concept, ConceptForm, ConceptTag, ConceptTagForm, DisplayableTag, LoginForm, Model, Msg(..), Page(..), Problem(..), ProfileForm, RegisterForm, Session, Tag, Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, conceptDecoder, conceptIdFromConceptTag, conceptTagDecoder, conceptTagsListDecoder, creatingTransactionSummary, displayableTagsListFrom, emptyConcept, emptyConceptForm, emptyProfileForm, emptyTransactionForm, emptyUser, formatBalance, formatBalanceFloat, formatBalancePlusFee, formatBalanceWithMultiplier, formatDate, idFromConcept, idFromDisplayable, indexUser, isDigitOrPlace, isNot, posixTime, profileDecoder, resourceIdsDecoder, secondsFromTgs, secondsFromTgsFloat, secondsFromTime, tagDecoder, tagFromConceptTagIfMatching, tgsFromTimeAndMultiplier, tgsLocale, timeFromTgs, timeFromTime, toIntMonth, transactionDecoder, txFeeFromTgs, txFeeIntFromTgs, userDecoder)

import Array exposing (Array)
import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Char exposing (isDigit)
import Dict exposing (Dict)
import Dict.Extra exposing (fromListBy)
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (Locale)
import Http
import Json.Decode as Decode exposing (Decoder, at, float, int, list, map7, string)
import Json.Decode.Pipeline exposing (optional, required)
import Loading
import Set exposing (Set)
import String exposing (toInt)
import Time exposing (Month)
import Url exposing (Url)


type alias Model =
    { navKey : Maybe Nav.Key
    , page : Page
    , navState : Maybe Navbar.State
    , loading : Loading.LoadingState
    , problems : List Problem
    , loginForm : LoginForm
    , registerForm : RegisterForm
    , profileForm : ProfileForm
    , transactionForm : TransactionForm
    , conceptForm : ConceptForm
    , conceptTagForm : ConceptTagForm
    , session : Session
    , apiActionResponse : ApiActionResponse
    , loggedInUser : User
    , concept : Concept
    , creatingTransaction : TransactionType
    , creatingTransactionFrom : TransactionFromType
    , transactions : List Transaction
    , pendingTransactions : List Transaction
    , txUsers : Dict String User
    , creatingTransactionWithUser : User
    , timeZone : Time.Zone
    , time : Time.Posix
    , conceptsList : List Concept
    , conceptTagsList : List ConceptTag
    , displayableTagsList : List DisplayableTag
    , conceptShowTagModel : Modal.Visibility
    }


type Page
    = Home
    | Login
    | Logout
    | Register
    | Profile
    | Transactions
    | Concepts String
    | ConceptsEdit String
    | ConceptsList
    | AddConcept
    | NotFound


type alias Session =
    { loginExpire : String
    , loginToken : String
    }


type alias ApiActionResponse =
    { status : Int
    , resourceId : Int
    , resourceIds : List Int
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
    , balance : Int
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


type alias ConceptTag =
    { id : Int
    , tag : String
    , conceptId : Int
    , order : Int
    }


type alias DisplayableTag =
    { id : Int
    , index : String
    , summary : String
    , tags : List String
    }


type alias Transaction =
    { id : Int
    , initiatedDate : Time.Posix
    , confirmedDate : Time.Posix
    , fromUserId : Int
    , toUserId : Int
    , seconds : Int
    , multiplier : Float
    , txFee : Int
    , status : Int
    , description : String
    , fromUserBalance : Int
    , toUserBalance : Int
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
    , txFee : String
    }


type alias ConceptForm =
    { name : String
    , tags : List ConceptTag
    , tagsToDelete : Set Int
    , summary : String
    , full : String
    }


type alias ConceptTagForm =
    { tag : String }


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
    | Name
    | TagTag


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type TransactionType
    = TxNone
    | TxOffer
    | TxRequest


type TransactionFromType
    = TxFromTGs
    | TxFromTimeMul
    | TxFromNational


type Msg
    = ChangedUrl Url
    | ClickedLink UrlRequest
    | NavMsg Navbar.State
    | SubmittedLoginForm
    | SubmittedRegisterForm
    | SubmittedProfileForm
    | SubmittedTransactionForm
    | SubmittedConceptForm
    | SubmittedAddConceptTagForm
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
    | EnteredConceptName String
    | EnteredConceptTagCheckToDelete Int Bool
    | EnteredConceptSummary String
    | EnteredConceptFull String
    | EnteredAddConceptTag String
    | CompletedLogin (Result Http.Error Session)
    | GotRegisterJson (Result Http.Error ApiActionResponse)
    | LoadedUser (Result Http.Error User)
    | LoadedProfile (Result Http.Error ProfileForm)
    | LoadedConcept (Result Http.Error Concept)
    | LoadedConceptTags (Result Http.Error (List ConceptTag))
    | ConceptTagDeleted (Result Http.Error ApiActionResponse)
    | GotUpdateProfileJson (Result Http.Error ApiActionResponse)
    | TransactionState TransactionType
    | TransactionFromState TransactionFromType
    | AddedTransaction (Result Http.Error ApiActionResponse)
    | AddedConcept (Result Http.Error ApiActionResponse)
    | AddedConceptTag Int String (Result Http.Error ApiActionResponse)
    | LoadedTransactions (Result Http.Error (List Transaction))
    | LoadedTxUsers (Result Http.Error (List User))
    | LoadedTransactionUserWithBalance (Result Http.Error User)
    | AcceptedTransaction (Result Http.Error ApiActionResponse)
    | RejectedTransaction (Result Http.Error ApiActionResponse)
    | LoadedConcepts (Result Http.Error (List Concept))
    | LoadedConceptTagsList (Result Http.Error (List ConceptTag))
    | AcceptTransaction Int
    | RejectTransaction Int
    | ButtonTransactionCheckBalance
    | AdjustTimeZone Time.Zone
    | TimeTick Time.Posix
    | ButtonConceptAddTag
    | ButtonConceptDeleteSelectedTags
    | CloseConceptAddTagModal



-- FORMATTERS AND LOCALS


tgsLocale : Locale
tgsLocale =
    Locale 4 "" "." "−" "" "" ""


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


secondsFromTime : String -> Int
secondsFromTime time =
    let
        timeParts =
            Array.fromList (String.split ":" (timeFromTime time))

        hours =
            Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (Array.get 0 timeParts)))

        minutes =
            Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (Array.get 1 timeParts)))

        seconds =
            Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (Array.get 2 timeParts)))
    in
    (hours * (60 * 60)) + (minutes * 60) + seconds


tgsFromTimeAndMultiplier : String -> String -> String
tgsFromTimeAndMultiplier time multiplier =
    let
        total =
            secondsFromTime time

        multiplied =
            toFloat total * Maybe.withDefault 1.0 (String.toFloat multiplier)
    in
    format tgsLocale (multiplied / (60.0 * 60.0))


secondsFromTgsFloat : String -> Float
secondsFromTgsFloat tgs =
    Maybe.withDefault 0 (String.toFloat tgs) * (60.0 * 60.0)


secondsFromTgs : String -> Int
secondsFromTgs tgs =
    round (secondsFromTgsFloat tgs)


txFeeIntFromTgs : String -> Int
txFeeIntFromTgs tgs =
    max 1 (floor (0.0002 * secondsFromTgsFloat tgs))


txFeeFromTgs : String -> String
txFeeFromTgs tgs =
    let
        fee =
            txFeeIntFromTgs tgs

        feeSec =
            String.padLeft 2 '0' (String.fromInt (remainderBy 60 fee))

        feeMinInt =
            fee // 60

        feeHour =
            String.padLeft 2 '0' (String.fromInt (fee // (60 * 60)))

        feeMin =
            String.padLeft 2 '0' (String.fromInt (remainderBy 60 feeMinInt))
    in
    feeHour ++ ":" ++ feeMin ++ ":" ++ feeSec


timeFromTime : String -> String
timeFromTime time =
    let
        timeParts =
            Array.fromList (String.split ":" time)

        hours =
            String.padLeft 2 '0' (Maybe.withDefault "" (Array.get 0 timeParts))

        minutes =
            String.padLeft 2 '0' (String.slice 0 2 (Maybe.withDefault "" (Array.get 1 timeParts)))

        seconds =
            String.padLeft 2 '0' (String.slice 0 2 (Maybe.withDefault "" (Array.get 2 timeParts)))
    in
    hours ++ ":" ++ minutes ++ ":" ++ seconds


timeFromTgs : String -> String -> String
timeFromTgs tgs multiplier =
    let
        divider =
            Maybe.withDefault 1 (String.toFloat multiplier)

        tgsFloat =
            Maybe.withDefault 0 (String.toFloat (String.filter isDigitOrPlace tgs))

        divided =
            tgsFloat / divider

        tgsAsSecondsInt =
            round (divided * 60 * 60)

        tgsSec =
            String.padLeft 2 '0' (String.fromInt (remainderBy 60 tgsAsSecondsInt))

        tgsMinInt =
            tgsAsSecondsInt // 60

        tgsHour =
            String.padLeft 2 '0' (String.fromInt (tgsAsSecondsInt // (60 * 60)))

        tgsMin =
            String.padLeft 2 '0' (String.fromInt (remainderBy 60 tgsMinInt))
    in
    tgsHour ++ ":" ++ tgsMin ++ ":" ++ tgsSec


isDigitOrPlace : Char -> Bool
isDigitOrPlace char =
    if isDigit char || char == '.' then
        True

    else
        False


isNot : Int -> Int -> Bool
isNot a b =
    if a == b then
        False

    else
        True


formatBalanceFloat : Float -> String
formatBalanceFloat balance =
    format tgsLocale (balance / 3600)


formatBalance : Int -> String
formatBalance balance =
    formatBalanceFloat (toFloat balance)


formatBalanceWithMultiplier : Int -> Float -> String
formatBalanceWithMultiplier balance multiplier =
    formatBalanceFloat (toFloat balance * multiplier)


formatBalancePlusFee : Int -> Int -> String
formatBalancePlusFee balance fee =
    formatBalanceFloat (toFloat (balance + fee))


creatingTransactionSummary : Model -> String
creatingTransactionSummary model =
    let
        valCost =
            if model.creatingTransaction == TxOffer then
                "cost"

            else
                "value"

        plusMinus =
            if model.creatingTransaction == TxOffer then
                "+"

            else
                "-"

        tgs =
            Maybe.withDefault 0 (String.toFloat model.transactionForm.tgs)

        tgsAsSeconds =
            tgs * 60 * 60

        txFee =
            toFloat (secondsFromTime model.transactionForm.txFee)

        transactionTgs =
            if model.creatingTransaction == TxOffer then
                tgsAsSeconds + txFee

            else
                tgsAsSeconds - txFee
    in
    " "
        ++ formatDate model model.time
        ++ ", "
        ++ valCost
        ++ " to you: "
        ++ formatBalanceFloat transactionTgs
        ++ "TGs, from ("
        ++ model.transactionForm.tgs
        ++ "TGs or "
        ++ model.transactionForm.time
        ++ " * "
        ++ model.transactionForm.multiplier
        ++ ") "
        ++ plusMinus
        ++ " "
        ++ model.transactionForm.txFee
        ++ " [Transaction Fee]"



-- INDEXERS


indexUser : User -> ( String, User )
indexUser user =
    ( String.fromInt user.id, user )


idFromConcept : Concept -> Int
idFromConcept concept =
    concept.id


idFromDisplayable : DisplayableTag -> Int
idFromDisplayable dTag =
    dTag.id


conceptIdFromConceptTag : ConceptTag -> Int
conceptIdFromConceptTag conceptTag =
    conceptTag.conceptId


tagFromConceptTagIfMatching : Int -> ConceptTag -> Maybe String
tagFromConceptTagIfMatching conceptId conceptTag =
    if conceptTag.conceptId == conceptId then
        Just conceptTag.tag

    else
        Nothing


displayableTagFrom : List ConceptTag -> Dict Int Concept -> Int -> DisplayableTag
displayableTagFrom conceptTags concepts conceptId =
    let
        tags =
            List.filterMap (tagFromConceptTagIfMatching conceptId) conceptTags

        index =
            case List.head tags of
                Just tag ->
                    tag

                Nothing ->
                    ""

        maybeConcept =
            Dict.get conceptId concepts

        summary =
            case maybeConcept of
                Just concept ->
                    concept.summary

                Nothing ->
                    ""
    in
    { id = conceptId
    , index = index
    , summary = summary
    , tags = tags
    }


displayableTagsListFrom : List ConceptTag -> List Concept -> List DisplayableTag
displayableTagsListFrom conceptTags concepts =
    let
        conceptIdList =
            Set.toList (Set.fromList (List.map conceptIdFromConceptTag conceptTags))

        groupedConcepts =
            fromListBy idFromConcept concepts

        dTags =
            List.map (displayableTagFrom conceptTags groupedConcepts) conceptIdList
    in
    dTags



-- EMPTIES


emptyUser : User
emptyUser =
    { id = 0
    , firstName = ""
    , midNames = ""
    , lastName = ""
    , location = ""
    , email = ""
    , mobile = ""
    , permissions = 0
    , balance = 0
    }


emptyConcept : Concept
emptyConcept =
    { id = 0
    , name = ""
    , summary = ""
    , full = ""
    , tags = []
    }


emptyConceptForm : ConceptForm
emptyConceptForm =
    { name = ""
    , tags = []
    , tagsToDelete = Set.empty
    , summary = ""
    , full = ""
    }


emptyProfileForm : ProfileForm
emptyProfileForm =
    { id = 0
    , firstName = ""
    , midNames = ""
    , lastName = ""
    , location = ""
    , email = ""
    , mobile = ""
    }


emptyTransactionForm : TransactionForm
emptyTransactionForm =
    { email = ""
    , tgs = ""
    , time = ""
    , multiplier = "1"
    , description = ""
    , txFee = "00:00:01"
    }



-- DECODERS


resourceIdsDecoder : Decoder (List Int)
resourceIdsDecoder =
    list int


apiActionDecoder : Decoder ApiActionResponse
apiActionDecoder =
    Decode.succeed ApiActionResponse
        |> required "status" int
        |> optional "resourceId" int 0
        |> optional "resourceIds" resourceIdsDecoder []


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
        |> optional "Balance" int 0


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


conceptTagsListDecoder : Decoder (List ConceptTag)
conceptTagsListDecoder =
    list conceptTagDecoder


tagDecoder : Decoder Tag
tagDecoder =
    Decode.succeed Tag
        |> required "ID" int
        |> required "Order" int
        |> required "Tag" string


conceptTagDecoder : Decoder ConceptTag
conceptTagDecoder =
    Decode.succeed ConceptTag
        |> required "ID" int
        |> required "Tag" string
        |> required "ConceptId" int
        |> required "Order" int


posixTime : Decode.Decoder Time.Posix
posixTime =
    Decode.int
        |> Decode.andThen
            (\ms -> Decode.succeed <| Time.millisToPosix ms)


transactionDecoder : Decoder Transaction
transactionDecoder =
    Decode.succeed Transaction
        |> required "ID" int
        |> required "InitiatedDate" posixTime
        |> required "ConfirmedDate" posixTime
        |> required "FromUserId" int
        |> required "ToUserId" int
        |> required "Seconds" int
        |> required "Multiplier" float
        |> required "TxFee" int
        |> required "Status" int
        |> required "Description" string
        |> required "FromUserBalance" int
        |> required "ToUserBalance" int



-- AUTH HEADER


authHeader : String -> Http.Header
authHeader token =
    Http.header "authorization" ("Bearer " ++ token)
