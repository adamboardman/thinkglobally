module Transaction exposing (TransactionTrimmedForm(..), loadTransactions, loadTxUsers, pageTransaction, transaction, transactionFieldsToValidate, transactionListDecoder, transactionPostDecoder, transactionSummary, transactionTrimFields, transactionUpdateForm, transactionValidate, txUsersListDecoder, validateField, viewCreateTransactionForm)

import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Table as Table exposing (Row)
import Dict exposing (Dict)
import FormValidation exposing (viewProblem)
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (usLocale)
import Html exposing (Html, div, h4, p, text, ul)
import Html.Attributes as Attributes exposing (class, for, href, step)
import Html.Events exposing (onSubmit)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, at, dict, field, int, list, map2)
import Json.Encode as Encode
import Loading
import Types exposing (ApiPostResponse, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionType(..), User, ValidatedField(..), authHeader, tgsLocale, transactionDecoder, userDecoder)


transactionFieldsToValidate : List ValidatedField
transactionFieldsToValidate =
    [ Email
    , Time
    , Multiplier
    ]


transactionSummary : Dict String User -> Transaction -> Row msg
transactionSummary txUsers tx =
    let
        fromUser =
            Dict.get (String.fromInt tx.fromUserId) txUsers

        toUser =
            Dict.get (String.fromInt tx.toUserId) txUsers

        fromUserName =
            case fromUser of
                Just user ->
                    user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                Nothing ->
                    String.fromInt tx.fromUserId

        toUserName =
            case toUser of
                Just user ->
                    user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                Nothing ->
                    String.fromInt tx.toUserId

        time =
            ((toFloat tx.seconds * tx.multiplier) - toFloat tx.txFee) / 3600

        balance =
            0
    in
    Table.tr []
        [ Table.td [] [ text fromUserName ]
        , Table.td [] [ text toUserName ]
        , Table.td [] [ text (format tgsLocale time) ]
        , Table.td [] [ text (format tgsLocale balance) ]
        ]


pendingTransactionSummary : Model -> Transaction -> Row msg
pendingTransactionSummary model tx =
    let
        fromUser =
            Dict.get (String.fromInt tx.fromUserId) model.txUsers

        toUser =
            Dict.get (String.fromInt tx.toUserId) model.txUsers

        fromUserName =
            case fromUser of
                Just user ->
                    user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                Nothing ->
                    String.fromInt tx.fromUserId

        toUserName =
            case toUser of
                Just user ->
                    user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                Nothing ->
                    String.fromInt tx.toUserId

        time =
            ((toFloat tx.seconds * tx.multiplier) - toFloat tx.txFee) / 3600

        status =
            case tx.status of
                1 ->
                    if tx.fromUserId == model.loggedInUser.id then
                        "Offer pending"

                    else
                        "Accept or Reject Offer"

                2 ->
                    if tx.toUserId == model.loggedInUser.id then
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
    in
    Table.tr []
        [ Table.td [] [ text fromUserName ]
        , Table.td [] [ text toUserName ]
        , Table.td [] [ text (format tgsLocale time) ]
        , Table.td [] [ text status ]
        ]


pageTransaction : Model -> List (Html Msg)
pageTransaction model =
    [ h4 [] [ text "Recent Transactions" ]
    , Table.table
        { options = [ Table.striped, Table.hover ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ text "From" ]
                , Table.th [] [ text "To" ]
                , Table.th [] [ text "TGs" ]
                , Table.th [] [ text "Balance" ]
                ]
        , tbody =
            Table.tbody []
                (List.map
                    (transactionSummary model.txUsers)
                    model.transactions
                )
        }
    , h4 [] [ text "Pending Transactions" ]
    , Table.table
        { options = [ Table.striped, Table.hover ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ text "From" ]
                , Table.th [] [ text "To" ]
                , Table.th [] [ text "TGs" ]
                , Table.th [] [ text "Status" ]
                ]
        , tbody =
            Table.tbody []
                (List.map
                    (pendingTransactionSummary model)
                    model.pendingTransactions
                )
        }
    , h4 [] [ text "Create Transaction" ]
    , ButtonGroup.radioButtonGroup []
        [ ButtonGroup.radioButton
            (model.creatingTransaction == TxNone)
            [ Button.primary, Button.onClick <| TransactionState TxNone ]
            [ text "Hidden" ]
        , ButtonGroup.radioButton
            (model.creatingTransaction == TxOffer)
            [ Button.primary, Button.onClick <| TransactionState TxOffer ]
            [ text "Offer" ]
        , ButtonGroup.radioButton
            (model.creatingTransaction == TxRequest)
            [ Button.primary, Button.onClick <| TransactionState TxRequest ]
            [ text "Request" ]
        ]
    , if model.creatingTransaction == TxNone then
        text ""

      else
        viewCreateTransactionForm model
    ]


viewCreateTransactionForm : Model -> Html Msg
viewCreateTransactionForm model =
    Form.form [ onSubmit SubmittedTransactionForm ]
        [ Form.group []
            [ Form.label [ for "email" ]
                [ if model.creatingTransaction == TxOffer then
                    text "Offer to Recipient Email address"

                  else
                    text "Request From Email address"
                ]
            , Input.email
                [ Input.id "email"
                , Input.placeholder "Email"
                , Input.onInput EnteredTransactionEmail
                , Input.value model.transactionForm.email
                ]
            , Form.invalidFeedback []
                [ if model.creatingTransaction == TxOffer then
                    text "Please enter recipient email address"

                  else
                    text "Please enter the email address you are requesting the transaction from"
                ]
            ]
        , Form.group []
            [ Form.label [ for "time" ] [ text "Time (HH:mm)" ]
            , Input.time
                [ Input.id "time"
                , Input.placeholder "Time"
                , Input.onInput EnteredTransactionTime
                , Input.value model.transactionForm.time
                ]
            , Form.invalidFeedback [] [ text "Please enter the time duration for the transaction" ]
            ]
        , Form.group []
            [ Form.label [ for "multiplier" ] [ text "Multiplier" ]
            , Input.number
                [ Input.id "multiplier"
                , Input.attrs [ Attributes.min "1", Attributes.max "3", Attributes.step "0.01" ]
                , Input.placeholder "Multiplier"
                , Input.onInput EnteredTransactionMultiplier
                , Input.value model.transactionForm.multiplier
                ]
            , Form.invalidFeedback [] [ text "Please enter the transaction multiplier, defaults to one" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Submit Transaction" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading
        ]


transactionUpdateForm : (TransactionForm -> TransactionForm) -> Model -> ( Model, Cmd Msg )
transactionUpdateForm transform model =
    ( { model | transactionForm = transform model.transactionForm }, Cmd.none )


transactionValidate : TransactionForm -> Result (List Problem) TransactionTrimmedForm
transactionValidate form =
    let
        trimmedForm =
            transactionTrimFields form
    in
    case List.concatMap (validateField trimmedForm) transactionFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : TransactionTrimmedForm -> ValidatedField -> List Problem
validateField (TransactionTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

                else if String.contains "@" form.email then
                    []

                else
                    [ "email must contain '@'" ]

            Time ->
                let
                    parts =
                        String.split ":" form.time
                in
                if String.isEmpty form.time then
                    [ "time can't be blank." ]

                else if List.length parts == 2 then
                    []

                else
                    [ "time must contain three parts separated by :'s" ]

            Multiplier ->
                let
                    multiplier =
                        Maybe.withDefault 0 (String.toFloat form.multiplier)
                in
                if multiplier < 1 || multiplier > 3 then
                    [ "Multiplier must be between 1 and 3." ]

                else
                    []

            _ ->
                []


type TransactionTrimmedForm
    = TransactionTrimmed TransactionForm


transactionTrimFields : TransactionForm -> TransactionTrimmedForm
transactionTrimFields form =
    TransactionTrimmed
        { email = String.trim form.email
        , time = String.trim form.time
        , multiplier = String.trim form.multiplier
        }



-- HTTP


transaction : Model -> TransactionTrimmedForm -> Cmd Msg
transaction model (TransactionTrimmed form) =
    let
        status =
            if model.creatingTransaction == TxOffer then
                1

            else
                2

        fromId =
            if model.creatingTransaction == TxOffer then
                model.loggedInUser.id

            else
                0

        toId =
            if model.creatingTransaction == TxOffer then
                0

            else
                model.loggedInUser.id

        timeParts =
            String.split ":" form.time

        seconds =
            (Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (List.head timeParts))) * 60 * 60)
                + (Maybe.withDefault 0 (String.toInt (Maybe.withDefault "0" (List.head (Maybe.withDefault [] (List.tail timeParts))))) * 60)

        body =
            Encode.object
                [ ( "Email", Encode.string form.email )
                , ( "Seconds", Encode.int seconds )
                , ( "Multiplier", Encode.float (Maybe.withDefault 0 (String.toFloat form.multiplier)) )
                , ( "Status", Encode.int status )
                , ( "FromUserId", Encode.int fromId )
                , ( "ToUserId", Encode.int toId )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "/api/transactions"
        , expect = Http.expectJson GotTransactionJson transactionPostDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


transactionPostDecoder : Decoder ApiPostResponse
transactionPostDecoder =
    map2 ApiPostResponse
        (at [ "status" ] int)
        (at [ "resourceId" ] int)


loadTransactions : Model -> Cmd Msg
loadTransactions model =
    Http.request
        { method = "GET"
        , url = "/api/transactions"
        , expect = Http.expectJson LoadedTransactions transactionListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
    list transactionDecoder


loadTxUsers : Model -> Cmd Msg
loadTxUsers model =
    Http.request
        { method = "GET"
        , url = "/api/users"
        , expect = Http.expectJson LoadedTxUsers txUsersListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


txUsersListDecoder : Decoder (List User)
txUsersListDecoder =
    list userDecoder