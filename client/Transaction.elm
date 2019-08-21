module Transaction exposing (TransactionTrimmedForm(..), acceptTransaction, loadTransactions, loadTxUsers, pageTransaction, pendingTransactionSummary, rejectTransaction, transaction, transactionFieldsToValidate, transactionListDecoder, transactionSummary, transactionTrimFields, transactionUpdateForm, transactionValidate, txUsersListDecoder, validateField, viewCreateTransactionForm)

import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Table as Table exposing (Row, rowAttr)
import Dict exposing (Dict)
import FormValidation exposing (viewProblem)
import FormatNumber exposing (format)
import Html exposing (Html, div, h4, text, ul)
import Html.Attributes as Attributes exposing (class, for, style)
import Html.Events exposing (onSubmit)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, field, list)
import Json.Encode as Encode
import Loading
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, formatDate, secondsFromTime, tgsLocale, transactionDecoder, userDecoder)


transactionFieldsToValidate : List ValidatedField
transactionFieldsToValidate =
    [ Email
    , Time
    , Multiplier
    ]


transactionSummary : Model -> Transaction -> Row msg
transactionSummary model tx =
    let
        date =
            if Time.posixToMillis tx.initiatedDate > 0 then
                formatDate model tx.initiatedDate

            else
                formatDate model tx.confirmedDate

        fromUser =
            Dict.get (String.fromInt tx.fromUserId) model.txUsers

        toUser =
            Dict.get (String.fromInt tx.toUserId) model.txUsers

        fromUserName =
            if model.loggedInUser.id == tx.fromUserId then
                "Yourself"

            else
                case fromUser of
                    Just user ->
                        user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                    Nothing ->
                        " (" ++ String.fromInt tx.fromUserId ++ ")"

        toUserName =
            if model.loggedInUser.id == tx.toUserId then
                "Yourself"

            else
                case toUser of
                    Just user ->
                        user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                    Nothing ->
                        " (" ++ String.fromInt tx.toUserId ++ ")"

        tgsIn =
            if model.loggedInUser.id == tx.toUserId then
                format tgsLocale (((toFloat tx.seconds * tx.multiplier) - toFloat tx.txFee) / 3600)

            else
                ""

        tgsOut =
            if model.loggedInUser.id == tx.fromUserId then
                format tgsLocale (((toFloat tx.seconds * tx.multiplier) - toFloat tx.txFee) / 3600)

            else
                ""

        status =
            case tx.status of
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

        balance =
            if model.loggedInUser.id == tx.fromUserId then
                toFloat tx.fromUserBalance / 3600

            else
                toFloat tx.toUserBalance / 3600
    in
    Table.tr
        [ if tx.status > 4 then
            rowAttr (style "color" "grey")

          else
            rowAttr (style "" "")
        ]
        [ Table.td [] [ text date ]
        , Table.td [] [ text fromUserName ]
        , Table.td [] [ text toUserName ]
        , Table.td [] [ text status ]
        , Table.td [] [ text tgsIn ]
        , Table.td [] [ text tgsOut ]
        , Table.td [] [ text (format tgsLocale balance) ]
        ]


pendingTransactionSummary : Model -> Transaction -> Row Msg
pendingTransactionSummary model tx =
    let
        date =
            if Time.posixToMillis tx.initiatedDate > 0 then
                formatDate model tx.initiatedDate

            else
                formatDate model tx.confirmedDate

        fromUser =
            Dict.get (String.fromInt tx.fromUserId) model.txUsers

        toUser =
            Dict.get (String.fromInt tx.toUserId) model.txUsers

        fromUserName =
            if model.loggedInUser.id == tx.fromUserId then
                "Yourself"

            else
                case fromUser of
                    Just user ->
                        user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                    Nothing ->
                        String.fromInt tx.fromUserId

        toUserName =
            if model.loggedInUser.id == tx.toUserId then
                "Yourself"

            else
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

                _ ->
                    ""
    in
    Table.tr []
        [ Table.td [] [ text date ]
        , Table.td [] [ text fromUserName ]
        , Table.td [] [ text toUserName ]
        , Table.td [] [ text (format tgsLocale time) ]
        , Table.td [] [ text status ]
        , Table.td []
            [ if (tx.status == 1 && tx.toUserId == model.loggedInUser.id) || (tx.status == 2 && tx.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| AcceptTransaction tx.id ] [ text "Accept" ]

              else
                text ""
            ]
        , Table.td []
            [ if (tx.status == 1 && tx.toUserId == model.loggedInUser.id) || (tx.status == 2 && tx.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| RejectTransaction tx.id ] [ text "Reject" ]

              else
                text ""
            ]
        ]


pageTransaction : Model -> List (Html Msg)
pageTransaction model =
    [ h4 [] [ text "Recent Transactions" ]
    , Table.table
        { options = [ Table.striped, Table.hover ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ text "Date" ]
                , Table.th [] [ text "From" ]
                , Table.th [] [ text "To" ]
                , Table.th [] [ text "Status" ]
                , Table.th [] [ text "TGs In" ]
                , Table.th [] [ text "TGs Out" ]
                , Table.th [] [ text "Balance" ]
                ]
        , tbody =
            Table.tbody []
                (List.map
                    (transactionSummary model)
                    model.transactions
                )
        }
    , h4 [] [ text "Pending Transactions" ]
    , Table.table
        { options = [ Table.striped, Table.hover ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ text "Date" ]
                , Table.th [] [ text "From" ]
                , Table.th [] [ text "To" ]
                , Table.th [] [ text "TGs" ]
                , Table.th [] [ text "Status" ]
                , Table.th [] [ text "" ]
                , Table.th [] [ text "" ]
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
        div [] [ text "Select Offer or Request to creat a new transaction" ]

      else
        viewCreateTransactionForm model
    ]


viewCreateTransactionForm : Model -> Html Msg
viewCreateTransactionForm model =
    Grid.container []
        [ Form.form [ onSubmit SubmittedTransactionForm ]
            [ Grid.row []
                [ Grid.col []
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
                    ]
                ]
            , Grid.row []
                [ Grid.col []
                    [ Form.group []
                        [ Form.label [ for "tgs" ] [ text "TGs (living wage hours)" ]
                        , Input.text
                            [ Input.id "tgs"
                            , Input.placeholder "TGs"
                            , Input.onInput EnteredTransactionTGs
                            , Input.value model.transactionForm.tgs
                            ]
                        , Form.invalidFeedback [] [ text "Please enter the TGs for the transaction" ]
                        ]
                    ]
                , Grid.col []
                    [ Form.group []
                        [ Form.label [ for "time" ] [ text "Time (HH:mm:ss)" ]
                        , Input.text
                            [ Input.id "time"
                            , Input.placeholder "Time"
                            , Input.onInput EnteredTransactionTime
                            , Input.value model.transactionForm.time
                            ]
                        , Form.invalidFeedback [] [ text "Please enter the time duration for the transaction" ]
                        ]
                    ]
                , Grid.col []
                    [ Form.group []
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
                    ]
                ]
            , Grid.row []
                [ Grid.col []
                    [ Form.group []
                        [ Form.label [] [ text "Transaction Date:" ]
                        , text " "
                        , text (formatDate model model.time)
                        , text ", Transaction Value: "
                        , text model.transactionForm.tgs
                        , text "TGs = ("
                        , text model.transactionForm.time
                        , text " * "
                        , text model.transactionForm.multiplier
                        , text ") - 00:00:01 [Transaction Fee]"
                        ]
                    ]
                ]
            , Grid.row []
                [ Grid.col []
                    [ Form.group []
                        [ Form.label [ for "description" ] [ text "Description" ]
                        , Textarea.textarea
                            [ Textarea.id "description"
                            , Textarea.rows 2
                            , Textarea.onInput EnteredTransactionDescription
                            , Textarea.value model.transactionForm.description
                            ]
                        , Form.invalidFeedback [] [ text "Please enter the transaction multiplier, defaults to one" ]
                        ]
                    ]
                ]
            , Grid.row []
                [ Grid.col []
                    [ ul [ class "error-messages" ]
                        (List.map viewProblem model.problems)
                    ]
                ]
            , Grid.row []
                [ Grid.col []
                    [ Button.button [ Button.primary ]
                        [ text "Submit Transaction" ]
                    ]
                ]
            , Grid.row []
                [ Grid.col []
                    [ Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading ]
                ]
            ]
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

                else if List.length parts == 3 then
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
        , tgs = String.trim form.tgs
        , time = String.trim form.time
        , multiplier = String.trim form.multiplier
        , description = String.trim form.description
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

        seconds =
            secondsFromTime form.time

        body =
            Encode.object
                [ ( "Email", Encode.string form.email )
                , ( "InitiatedDate", Encode.int (Time.posixToMillis model.time) )
                , ( "Seconds", Encode.int seconds )
                , ( "Multiplier", Encode.float (Maybe.withDefault 0 (String.toFloat form.multiplier)) )
                , ( "Status", Encode.int status )
                , ( "Description", Encode.string form.description )
                , ( "FromUserId", Encode.int fromId )
                , ( "ToUserId", Encode.int toId )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "/api/transactions"
        , expect = Http.expectJson AddedTransaction apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


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


acceptTransaction : Model -> Int -> Cmd Msg
acceptTransaction model txId =
    Http.request
        { method = "PATCH"
        , url = "/api/transactions/" ++ String.fromInt txId ++ "/accept"
        , expect = Http.expectJson AcceptedTransaction apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


rejectTransaction : Model -> Int -> Cmd Msg
rejectTransaction model txId =
    Http.request
        { method = "PATCH"
        , url = "/api/transactions/" ++ String.fromInt txId ++ "/reject"
        , expect = Http.expectJson RejectedTransaction apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
