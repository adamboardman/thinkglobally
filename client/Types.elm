module Types exposing (..)

import Array exposing (Array)
import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Char exposing (isDigit)
import Dict exposing (Dict)
import Dict.Extra exposing (fromListBy)
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (Decimals(..), Locale, System(..))
import Http
import Json.Decode as Decode exposing (Decoder, at, float, int, list, map8, string)
import Json.Decode.Pipeline exposing (optional, required)
import List.Extra
import Loading
import Set exposing (Set)
import String
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
    , pastTransactions : List Transaction
    , pendingTransactions : List Transaction
    , txUsers : Dict String User
    , creatingTransactionWithUser : User
    , timeZone : Time.Zone
    , time : Time.Posix
    , date : Time.Posix
    , conceptsList : List Concept
    , conceptTagsList : List ConceptTag
    , displayableTagsList : List DisplayableTag
    , conceptShowTagModel : Modal.Visibility
    , selectedTxId : Int
    , livingWage : LivingWage
    , livingWageLocation : LivingWageLocation
    , livingWageList : List LivingWage
    , livingWageLocationList : List LivingWageLocation
    , livingWageForm : LivingWageForm
    , livingWageLocationForm : LivingWageLocationForm
    , creatingStandingOrder : TransactionType
    , creatingStandingOrderFrom : TransactionFromType
    , creatingStandingOrderWithUser : User
    , standingOrderForm : StandingOrderForm
    , pastStandingOrders : List StandingOrder
    , pendingStandingOrders : List StandingOrder
    }


type Page
    = Home
    | Login
    | Logout
    | Register (Maybe String) (Maybe String)
    | Profile
    | PendingTransactions
    | PastTransactions
    | AddTransaction
    | Concepts String
    | ConceptsEdit String
    | ConceptsList
    | AddConcept
    | LivingWageLocationList
    | AddLivingWageLocation
    | LivingWageLocationEdit String
    | LivingWageList
    | AddLivingWage
    | LivingWageEdit String
    | AddStandingOrder
    | PendingStandingOrders
    | PastStandingOrders
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
    , locationId : Int
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


type alias LivingWageLocation =
    { id : Int
    , name : String
    , symbol : String
    }


type alias LivingWage =
    { id : Int
    , startDate : Time.Posix
    , stopDate : Time.Posix
    , locationId : Int
    , wage : Float
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
    , locationId : Int
    , standingOrderId : Int
    }


type alias StandingOrder =
    { id : Int
    , startDate : Time.Posix
    , stopDate : Time.Posix
    , confirmedDate : Time.Posix
    , processedUptoDate : Time.Posix
    , fromUserId : Int
    , toUserId : Int
    , seconds : Int
    , multiplier : Float
    , txFee : Int
    , status : Int
    , description : String
    , locationId : Int
    , frequency : Int
    }


type alias LoginForm =
    { email : String
    , password : String
    }


type alias RegisterForm =
    { email : String
    , password : String
    , password_confirm : String
    , verification : String
    }


type alias ProfileForm =
    { id : Int
    , firstName : String
    , midNames : String
    , lastName : String
    , location : String
    , locationId : Int
    , email : String
    , mobile : String
    }


type alias TransactionForm =
    { email : String
    , date : Time.Posix
    , tgs : String
    , timeH : String
    , timeM : String
    , timeS : String
    , multiplier : String
    , locationId : Int
    , national : String
    , description : String
    , txFee : String
    }


type alias StandingOrderForm =
    { email : String
    , startDate : String
    , stopDate : String
    , tgs : String
    , timeH : String
    , timeM : String
    , timeS : String
    , multiplier : String
    , locationId : Int
    , national : String
    , description : String
    , txFee : String
    , frequency : FrequencyFormType
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


type alias LivingWageForm =
    { startDate : String
    , stopDate : String
    , locationId : Int
    , wage : String
    }


type alias LivingWageLocationForm =
    { name : String
    , symbol : String
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
    | TGs
    | Multiplier
    | Name
    | TagTag
    | StartDate
    | StopDate


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


type FrequencyFormType
    = FrequencyDaily
    | FrequencyWeekly
    | FrequencyMonthly
    | FrequencyAnnually


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
    | EnteredTransactionTimeH String
    | EnteredTransactionTimeM String
    | EnteredTransactionTimeS String
    | EnteredTransactionMultiplier String
    | EnteredTransactionNational String
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
    | ViewTransaction Int
    | SubmittedLivingWageForm
    | SubmittedLivingWageLocationForm
    | EnteredLivingWageLocationName String
    | EnteredLivingWageLocationSymbol String
    | EnteredLivingWageWage String
    | LoadedLivingWage (Result Http.Error LivingWage)
    | LoadedLivingWages (Result Http.Error (List LivingWage))
    | LoadedLivingWageLocation (Result Http.Error LivingWageLocation)
    | LoadedLivingWageLocations (Result Http.Error (List LivingWageLocation))
    | AddedLivingWage (Result Http.Error ApiActionResponse)
    | AddedLivingWageLocation (Result Http.Error ApiActionResponse)
    | EnteredLivingWageStartDate String
    | EnteredLivingWageStopDate String
    | SelectedLocationId String
    | SelectedProfileLocationId String
    | SelectedTransactionLocationId String
    | StandingOrderState TransactionType
    | StandingOrderFromState TransactionFromType
    | EnteredStandingOrderEmail String
    | EnteredStandingOrderTGs String
    | EnteredStandingOrderTimeH String
    | EnteredStandingOrderTimeM String
    | EnteredStandingOrderTimeS String
    | EnteredStandingOrderMultiplier String
    | EnteredStandingOrderNational String
    | EnteredStandingOrderDescription String
    | EnteredStandingOrderStartDate String
    | EnteredStandingOrderStopDate String
    | ButtonStandingOrderCheckBalance
    | SelectedStandingOrderLocationId String
    | SelectedStandingOrderFrequency FrequencyFormType
    | SubmittedStandingOrderForm
    | AddedStandingOrder (Result Http.Error ApiActionResponse)
    | LoadedStandingOrderUserWithBalance (Result Http.Error User)
    | LoadedStandingOrders (Result Http.Error (List StandingOrder))
    | ViewStandingOrder Int
    | AcceptStandingOrder Int
    | RejectStandingOrder Int
    | WithdrawStandingOrder Int
    | StopStandingOrder Int
    | AcceptedStandingOrder (Result Http.Error ApiActionResponse)
    | RejectedStandingOrder (Result Http.Error ApiActionResponse)
    | StandingOrderDeleted (Result Http.Error ApiActionResponse)
    | StandingOrderStopped (Result Http.Error ApiActionResponse)



-- FORMATTERS AND LOCALS


tgsLocale : Locale
tgsLocale =
    Locale (Exact 4) Western " " "." "−" "" "" "" "" ""


nationalLocale : Locale
nationalLocale =
    Locale (Exact 2) Western " " "." "−" "" "" "" "" ""


nationalTaxLocale : Locale
nationalTaxLocale =
    Locale (Exact 3) Western " " "." "−" "" "" "" "" ""


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
    in
    year ++ "-" ++ month ++ "-" ++ day


formatDateTime : Model -> Time.Posix -> String
formatDateTime model date =
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


secondsFromTimeHMS : String -> String -> String -> Int
secondsFromTimeHMS timeH timeM timeS =
    let
        hours =
            Maybe.withDefault 0 (String.toInt timeH)

        minutes =
            Maybe.withDefault 0 (String.toInt timeM)

        seconds =
            Maybe.withDefault 0 (String.toInt timeS)
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


tgsFromTimeHMSAndMultiplier : String -> String -> String -> String -> String
tgsFromTimeHMSAndMultiplier timeH timeM timeS multiplier =
    let
        total =
            secondsFromTimeHMS timeH timeM timeS

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


padAndCapTimePart : String -> String
padAndCapTimePart part =
    String.padLeft 2 '0' (String.fromInt (min 60 (Maybe.withDefault 0 (String.toInt part))))


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


timeFromTgs : Int -> String
timeFromTgs tgs =
    let
        tgsSec =
            String.padLeft 2 '0' (String.fromInt (remainderBy 60 tgs))

        tgsMinInt =
            tgs // 60

        tgsHour =
            String.padLeft 2 '0' (String.fromInt (tgs // (60 * 60)))

        tgsMin =
            String.padLeft 2 '0' (String.fromInt (remainderBy 60 tgsMinInt))
    in
    tgsHour ++ ":" ++ tgsMin ++ ":" ++ tgsSec


intHoursFromTgs : String -> String -> String
intHoursFromTgs tgs multiplier =
    let
        divider =
            Maybe.withDefault 1 (String.toFloat multiplier)

        tgsFloat =
            Maybe.withDefault 0 (String.toFloat (String.filter isDigitOrPlace tgs))

        divided =
            tgsFloat / divider

        tgsAsSecondsInt =
            round (divided * 60 * 60)

        tgsHour =
            String.padLeft 2 '0' (String.fromInt (tgsAsSecondsInt // (60 * 60)))
    in
    tgsHour


intMinutesFromTgs : String -> String -> String
intMinutesFromTgs tgs multiplier =
    let
        divider =
            Maybe.withDefault 1 (String.toFloat multiplier)

        tgsFloat =
            Maybe.withDefault 0 (String.toFloat (String.filter isDigitOrPlace tgs))

        divided =
            tgsFloat / divider

        tgsAsSecondsInt =
            round (divided * 60 * 60)

        tgsMinInt =
            tgsAsSecondsInt // 60
    in
    String.padLeft 2 '0' (String.fromInt (remainderBy 60 tgsMinInt))


intSecondsFromTgs : String -> String -> String
intSecondsFromTgs tgs multiplier =
    let
        divider =
            Maybe.withDefault 1 (String.toFloat multiplier)

        tgsFloat =
            Maybe.withDefault 0 (String.toFloat (String.filter isDigitOrPlace tgs))

        divided =
            tgsFloat / divider

        tgsAsSecondsInt =
            round (divided * 60 * 60)
    in
    String.padLeft 2 '0' (String.fromInt (remainderBy 60 tgsAsSecondsInt))


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


isSelectedTx : Int -> Transaction -> Bool
isSelectedTx txId tx =
    tx.id == txId


isSelectedStandingOrder : Int -> StandingOrder -> Bool
isSelectedStandingOrder soId so =
    so.id == soId


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


formatNationalFloat : Float -> String
formatNationalFloat balance =
    format nationalLocale balance


formatNationalTaxFloat : Float -> String
formatNationalTaxFloat balance =
    format nationalTaxLocale balance


findLivingWageForLocationIdAndDate : Model -> Int -> Time.Posix -> LivingWage
findLivingWageForLocationIdAndDate model locationId date =
    let
        wagesForLocation =
            List.filter (\wage -> wage.locationId == locationId) model.livingWageList

        wagesForDate =
            List.filter (\wage -> (Time.posixToMillis date >= Time.posixToMillis wage.startDate) && (Time.posixToMillis date < Time.posixToMillis wage.stopDate)) wagesForLocation

        wageForMinDate =
            List.Extra.minimumBy (\wage -> Time.posixToMillis wage.startDate) wagesForLocation

        wageForMaxDate =
            List.Extra.maximumBy (\wage -> Time.posixToMillis wage.stopDate) wagesForLocation

        minOrMaxDate =
            case wageForMinDate of
                Just wage ->
                    if Time.posixToMillis date < Time.posixToMillis wage.startDate then
                        Maybe.withDefault emptyLivingWage wageForMinDate

                    else
                        Maybe.withDefault emptyLivingWage wageForMaxDate

                Nothing ->
                    emptyLivingWage
    in
    Maybe.withDefault minOrMaxDate (List.head wagesForDate)


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

        locationId =
            model.transactionForm.locationId

        livingWage =
            findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

        nationalValueWarning =
            if model.transactionForm.locationId > 0 && Time.posixToMillis livingWage.stopDate < Time.posixToMillis model.transactionForm.date then
                "WARNING: Living Wage values are only indicative as we haven't found the current value"

            else
                ""
    in
    " "
        ++ formatDateTime model model.time
        ++ ", "
        ++ valCost
        ++ " to you: "
        ++ formatBalanceFloat transactionTgs
        ++ "TGs, from ("
        ++ model.transactionForm.tgs
        ++ " TGs or "
        ++ padAndCapTimePart model.transactionForm.timeH
        ++ ":"
        ++ padAndCapTimePart model.transactionForm.timeM
        ++ ":"
        ++ padAndCapTimePart model.transactionForm.timeS
        ++ " * "
        ++ model.transactionForm.multiplier
        ++ ") "
        ++ plusMinus
        ++ " "
        ++ model.transactionForm.txFee
        ++ " [Transaction Fee] "
        ++ nationalValueWarning


frequencyStringFromType : FrequencyFormType -> String
frequencyStringFromType frequency =
    case frequency of
        FrequencyDaily ->
            "Day"

        FrequencyWeekly ->
            "Week"

        FrequencyMonthly ->
            "Month"

        FrequencyAnnually ->
            "Year"


frequencyStringFromInt : Int -> String
frequencyStringFromInt frequency =
    case frequency of
        1 ->
            "Daily"

        2 ->
            "Weekly"

        3 ->
            "Monthly"

        4 ->
            "Annually"

        _ ->
            ""


creatingStandingOrderSummary : Model -> String
creatingStandingOrderSummary model =
    let
        valCost =
            if model.creatingStandingOrder == TxOffer then
                "Cost"

            else
                "Value"

        plusMinus =
            if model.creatingStandingOrder == TxOffer then
                "+"

            else
                "-"

        tgs =
            Maybe.withDefault 0 (String.toFloat model.standingOrderForm.tgs)

        tgsAsSeconds =
            tgs * 60 * 60

        txFee =
            toFloat (secondsFromTime model.standingOrderForm.txFee)

        transactionTgs =
            if model.creatingStandingOrder == TxOffer then
                tgsAsSeconds + txFee

            else
                tgsAsSeconds - txFee

        frequency =
            frequencyStringFromType model.standingOrderForm.frequency
    in
    " "
        ++ valCost
        ++ " to you: "
        ++ formatBalanceFloat transactionTgs
        ++ "TGs, every: "
        ++ frequency
        ++ ", from ("
        ++ model.standingOrderForm.tgs
        ++ " TGs or "
        ++ padAndCapTimePart model.standingOrderForm.timeH
        ++ ":"
        ++ padAndCapTimePart model.standingOrderForm.timeM
        ++ ":"
        ++ padAndCapTimePart model.standingOrderForm.timeS
        ++ " * "
        ++ model.standingOrderForm.multiplier
        ++ ") "
        ++ plusMinus
        ++ " "
        ++ model.standingOrderForm.txFee
        ++ " [Transaction Fee]"


dateFromTransaction : Model -> Transaction -> String
dateFromTransaction model tx =
    if Time.posixToMillis tx.initiatedDate > 0 then
        formatDateTime model tx.initiatedDate

    else
        formatDateTime model tx.confirmedDate


userGivenAnId : Model -> Int -> Maybe User
userGivenAnId model userId =
    Dict.get (String.fromInt userId) model.txUsers


summaryUserGivenAnId : Model -> Int -> String
summaryUserGivenAnId model userId =
    if model.loggedInUser.id == userId then
        "Yourself"

    else
        case userGivenAnId model userId of
            Just user ->
                user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt userId ++ ")"

            Nothing ->
                String.fromInt userId


summaryTgsAsSeconds : Model -> Int -> Int -> Int -> Int -> Int
summaryTgsAsSeconds model status fromUserId seconds txFee =
    if fromUserId == model.loggedInUser.id then
        case status of
            1 ->
                seconds + txFee

            2 ->
                seconds - txFee

            3 ->
                seconds + txFee

            4 ->
                seconds - txFee

            5 ->
                seconds + txFee

            6 ->
                seconds - txFee

            _ ->
                0

    else
        seconds


tgsFromTransaction : Model -> Transaction -> Float
tgsFromTransaction model tx =
    if tx.fromUserId == model.loggedInUser.id then
        toFloat -(summaryTgsAsSeconds model tx.status tx.fromUserId tx.seconds tx.txFee) / 3600

    else
        toFloat (summaryTgsAsSeconds model tx.status tx.fromUserId tx.seconds tx.txFee) / 3600


tgsFromStandingOrder : Model -> StandingOrder -> Float
tgsFromStandingOrder model so =
    if so.fromUserId == model.loggedInUser.id then
        toFloat -(summaryTgsAsSeconds model so.status so.fromUserId so.seconds so.txFee) / 3600

    else
        toFloat (summaryTgsAsSeconds model so.status so.fromUserId so.seconds so.txFee) / 3600


transactionNewBalanceFrom : Model -> Transaction -> Int
transactionNewBalanceFrom model tx =
    case ( userGivenAnId model tx.fromUserId, tx.status ) of
        ( Just user, 1 ) ->
            user.balance - round (toFloat tx.seconds + toFloat tx.txFee)

        ( Just user, 2 ) ->
            user.balance - round (toFloat tx.seconds)

        ( Just user, 3 ) ->
            user.balance - round (toFloat tx.seconds + toFloat tx.txFee)

        ( Just user, 4 ) ->
            user.balance - round (toFloat tx.seconds)

        ( Just user, 5 ) ->
            user.balance - round (toFloat tx.seconds + toFloat tx.txFee)

        ( Just user, 6 ) ->
            user.balance - round (toFloat tx.seconds)

        _ ->
            0


transactionNewBalanceTo : Model -> Transaction -> Int
transactionNewBalanceTo model tx =
    case ( userGivenAnId model tx.toUserId, tx.status ) of
        ( Just user, 1 ) ->
            user.balance + round (toFloat tx.seconds)

        ( Just user, 2 ) ->
            user.balance + round (toFloat tx.seconds - toFloat tx.txFee)

        ( Just user, 3 ) ->
            user.balance + round (toFloat tx.seconds)

        ( Just user, 4 ) ->
            user.balance + round (toFloat tx.seconds - toFloat tx.txFee)

        ( Just user, 5 ) ->
            user.balance + round (toFloat tx.seconds)

        ( Just user, 6 ) ->
            user.balance + round (toFloat tx.seconds - toFloat tx.txFee)

        _ ->
            0


transactionStatus : Model -> Int -> Int -> Int -> String
transactionStatus model status fromUserId toUserId =
    case status of
        1 ->
            if fromUserId == model.loggedInUser.id then
                "Offer pending"

            else
                "Accept or Reject Offer"

        2 ->
            if toUserId == model.loggedInUser.id then
                "Request pending"

            else
                "Accept or Reject Request"

        3 ->
            "Offer Approved"

        4 ->
            "Request Approved"

        5 ->
            "Offer Rejected"

        6 ->
            "Request Rejected"

        _ ->
            ""


transactionActivity : Int -> String
transactionActivity status =
    case status of
        1 ->
            "Offer"

        2 ->
            "Request"

        3 ->
            "Offer"

        4 ->
            "Request"

        5 ->
            "Offer"

        6 ->
            "Request"

        _ ->
            ""



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
    , locationId = 0
    , email = ""
    , mobile = ""
    , permissions = 0
    , balance = 0
    }


emptySession : Session
emptySession =
    { loginExpire = "", loginToken = "" }


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
    , locationId = 0
    , email = ""
    , mobile = ""
    }


emptyTransactionForm : TransactionForm
emptyTransactionForm =
    { email = ""
    , date = Time.millisToPosix 0
    , tgs = ""
    , timeH = ""
    , timeM = ""
    , timeS = ""
    , multiplier = "1"
    , locationId = 0
    , national = ""
    , description = ""
    , txFee = "00:00:01"
    }


emptyStandingOrderForm : StandingOrderForm
emptyStandingOrderForm =
    { email = ""
    , startDate = ""
    , stopDate = ""
    , tgs = ""
    , timeH = ""
    , timeM = ""
    , timeS = ""
    , multiplier = "1"
    , locationId = 0
    , national = ""
    , description = ""
    , txFee = "00:00:01"
    , frequency = FrequencyMonthly
    }


emptyStandingOrder : StandingOrder
emptyStandingOrder =
    { id = 0
    , startDate = Time.millisToPosix 0
    , stopDate = Time.millisToPosix 0
    , confirmedDate = Time.millisToPosix 0
    , processedUptoDate = Time.millisToPosix 0
    , fromUserId = 0
    , toUserId = 0
    , seconds = 0
    , multiplier = 1.0
    , txFee = 0
    , status = 0
    , description = ""
    , locationId = 0
    , frequency = 3
    }


emptyLivingWage : LivingWage
emptyLivingWage =
    { id = 0
    , startDate = Time.millisToPosix 0
    , stopDate = Time.millisToPosix 0
    , locationId = 0
    , wage = 0.0
    }


emptyLivingWageForm : LivingWageForm
emptyLivingWageForm =
    { startDate = ""
    , stopDate = ""
    , locationId = 0
    , wage = ""
    }


emptyLivingWageLocation : LivingWageLocation
emptyLivingWageLocation =
    { id = 0
    , name = ""
    , symbol = ""
    }


emptyLivingWageLocationForm : LivingWageLocationForm
emptyLivingWageLocationForm =
    { name = ""
    , symbol = ""
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
        |> optional "LocationId" int 0
        |> optional "Email" string ""
        |> optional "Mobile" string ""
        |> optional "Permissions" int 0
        |> optional "Balance" int 0


profileDecoder : Decoder ProfileForm
profileDecoder =
    map8 ProfileForm
        (at [ "ID" ] int)
        (at [ "FirstName" ] string)
        (at [ "MidNames" ] string)
        (at [ "LastName" ] string)
        (at [ "Location" ] string)
        (at [ "LocationId" ] int)
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
        |> required "LocationId" int
        |> required "StandingOrderId" int


standingOrderDecoder : Decoder StandingOrder
standingOrderDecoder =
    Decode.succeed StandingOrder
        |> required "ID" int
        |> required "StartDate" posixTime
        |> required "StopDate" posixTime
        |> required "ConfirmedDate" posixTime
        |> required "ProcessedUptoDate" posixTime
        |> required "FromUserId" int
        |> required "ToUserId" int
        |> required "Seconds" int
        |> required "Multiplier" float
        |> required "TxFee" int
        |> required "Status" int
        |> required "Description" string
        |> required "LocationId" int
        |> required "Frequency" int


livingWageLocationDecoder : Decoder LivingWageLocation
livingWageLocationDecoder =
    Decode.succeed LivingWageLocation
        |> required "ID" int
        |> required "Name" string
        |> required "Symbol" string


livingWageDecoder : Decoder LivingWage
livingWageDecoder =
    Decode.succeed LivingWage
        |> required "ID" int
        |> required "StartDate" posixTime
        |> required "StopDate" posixTime
        |> required "LocationId" int
        |> required "Wage" float



-- AUTH HEADER


authHeader : String -> Http.Header
authHeader token =
    Http.header "authorization" ("Bearer " ++ token)
