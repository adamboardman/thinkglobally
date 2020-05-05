module TransactionCreate exposing (TransactionTrimmedForm(..), pageTransactionCreate, transaction, transactionCheckBalance, transactionFieldsToValidate, transactionTrimFields, transactionUpdateForm, transactionValidate, validateField, viewCreateTransactionForm)

import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import FormValidation exposing (viewProblem)
import Html exposing (Html, div, h4, text, ul)
import Html.Attributes as Attributes exposing (class, for)
import Html.Events exposing (onSubmit)
import Http exposing (emptyBody)
import Json.Encode as Encode
import Loading
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, creatingTransactionSummary, formatBalance, secondsFromTgs, txFeeIntFromTgs, userDecoder)


transactionFieldsToValidate : List ValidatedField
transactionFieldsToValidate =
    [ Email
    , Time
    , Multiplier
    ]


pageTransactionCreate : Model -> List (Html Msg)
pageTransactionCreate model =
    [ h4 [] [ text "Create Transaction" ]
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
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
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
            , if model.creatingTransaction == TxRequest then
                Grid.row []
                    [ Grid.col []
                        [ Form.row []
                            [ Form.col []
                                [ Button.button
                                    [ Button.secondary
                                    , Button.onClick ButtonTransactionCheckBalance
                                    , Button.disabled (String.length model.transactionForm.email == 0)
                                    ]
                                    [ text "Check balance" ]
                                ]
                            , Form.col []
                                [ text "Balance: "
                                , text (formatBalance model.creatingTransactionWithUser.balance)
                                ]
                            ]
                        ]
                    ]

              else
                Grid.row []
                    [ Grid.col []
                        [ Form.row []
                            [ Form.col []
                                [ text "Your balance: "
                                , text (formatBalance model.loggedInUser.balance)
                                ]
                            ]
                        ]
                    ]
            , ButtonGroup.radioButtonGroup []
                [ ButtonGroup.radioButton
                    (model.creatingTransactionFrom == TxFromTGs)
                    [ Button.primary, Button.onClick <| TransactionFromState TxFromTGs ]
                    [ text "Direct TGs" ]
                , ButtonGroup.radioButton
                    (model.creatingTransactionFrom == TxFromTimeMul)
                    [ Button.primary, Button.onClick <| TransactionFromState TxFromTimeMul ]
                    [ text "Time and Multiplier" ]
                , ButtonGroup.radioButton
                    (model.creatingTransactionFrom == TxFromNational)
                    [ Button.primary, Button.disabled True ]
                    [ text "Equivalent to national currency" ]
                ]
            , case model.creatingTransactionFrom of
                TxFromTGs ->
                    Grid.row []
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
                        ]

                TxFromTimeMul ->
                    Grid.row []
                        [ Grid.col []
                            [ Form.group []
                                [ Form.label [ for "timeH" ] [ text "Time (HH)" ]
                                , Input.text
                                    [ Input.id "timeH"
                                    , Input.placeholder "Hours"
                                    , Input.onInput EnteredTransactionTimeH
                                    , Input.value model.transactionForm.timeH
                                    ]
                                ]
                            ]
                        , Grid.col []
                            [ Form.group []
                                [ Form.label [ for "timeM" ] [ text "Time (mm)" ]
                                , Input.text
                                    [ Input.id "timeM"
                                    , Input.placeholder "Minutes"
                                    , Input.onInput EnteredTransactionTimeM
                                    , Input.value model.transactionForm.timeM
                                    ]
                                ]
                            ]
                        , Grid.col []
                            [ Form.group []
                                [ Form.label [ for "timeS" ] [ text "Time (ss)" ]
                                , Input.text
                                    [ Input.id "timeS"
                                    , Input.placeholder "Seconds"
                                    , Input.onInput EnteredTransactionTimeS
                                    , Input.value model.transactionForm.timeS
                                    ]
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

                TxFromNational ->
                    Grid.row []
                        [ Grid.col [] [] ]
            , Grid.row []
                [ Grid.col []
                    [ Form.group []
                        [ Form.label [] [ text "Transaction Date:" ]
                        , text (creatingTransactionSummary model)
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
        , timeH = String.trim form.timeH
        , timeM = String.trim form.timeM
        , timeS = String.trim form.timeS
        , multiplier = String.trim form.multiplier
        , description = String.trim form.description
        , txFee = String.trim form.txFee
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
            secondsFromTgs form.tgs

        multiplier =
            Maybe.withDefault 0 (String.toFloat form.multiplier)

        txFee =
            txFeeIntFromTgs form.tgs

        body =
            Encode.object
                [ ( "Email", Encode.string form.email )
                , ( "InitiatedDate", Encode.int (Time.posixToMillis model.time) )
                , ( "Seconds", Encode.int seconds )
                , ( "Multiplier", Encode.float multiplier )
                , ( "Status", Encode.int status )
                , ( "Description", Encode.string form.description )
                , ( "FromUserId", Encode.int fromId )
                , ( "ToUserId", Encode.int toId )
                , ( "TxFee", Encode.int txFee )
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


transactionCheckBalance : Model -> Cmd Msg
transactionCheckBalance model =
    Http.request
        { method = "GET"
        , url = "/api/users?Email=" ++ model.transactionForm.email
        , expect = Http.expectJson LoadedTransactionUserWithBalance userDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
