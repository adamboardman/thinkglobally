module StandingOrderCreate exposing (..)

import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Select as Select
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Dict
import FormValidation exposing (viewProblem)
import Html exposing (Html, div, h4, text, ul)
import Html.Attributes exposing (for)
import Html.Events exposing (onSubmit)
import Http exposing (emptyBody)
import Iso8601
import Json.Encode as Encode
import Loading
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), StandingOrderForm, Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, creatingStandingOrderSummary, formatBalance, secondsFromTgs, txFeeIntFromTgs, userDecoder)


standingOrderFieldsToValidate : List ValidatedField
standingOrderFieldsToValidate =
    [ Email
    , TGs
    , Multiplier
    ]


pageStandingOrderCreate : Model -> List (Html Msg)
pageStandingOrderCreate model =
    [ h4 [] [ text "Create StandingOrder" ]
    , Grid.container []
        [ ButtonGroup.radioButtonGroup []
            [ ButtonGroup.radioButton
                (model.creatingStandingOrder == TxNone)
                [ Button.primary, Button.onClick <| StandingOrderState TxNone ]
                [ text "Hidden" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrder == TxOffer)
                [ Button.primary, Button.onClick <| StandingOrderState TxOffer ]
                [ text "Offer" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrder == TxRequest)
                [ Button.primary, Button.onClick <| StandingOrderState TxRequest ]
                [ text "Request" ]
            ]
        , if model.creatingStandingOrder == TxNone then
            div [] [ text "Select Offer or Request to create a new Standing Order" ]

          else
            viewCreateStandingOrderForm model
        ]
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]


isUserMatchingStandingOrderEmail : Model -> User -> Bool
isUserMatchingStandingOrderEmail model user =
    if String.length model.standingOrderForm.email > 0 then
        let
            lowerEmail =
                String.toLower model.standingOrderForm.email
        in
        not (user.id == model.loggedInUser.id)
            && String.contains lowerEmail (String.toLower (String.concat [ user.firstName, " ", user.midNames, " ", user.lastName, " ", user.email ]))

    else
        False


viewSuggestedTransacte : User -> Html Msg
viewSuggestedTransacte user =
    Button.button [ Button.secondary, Button.onClick <| EnteredStandingOrderEmail user.email ] [ text (String.concat [ user.firstName, " ", user.midNames, " ", user.lastName, " (", user.email, ")", " " ]) ]


viewSelectableLocation : StandingOrderForm -> Types.LivingWageLocation -> Select.Item Msg
viewSelectableLocation form livingWageLocation =
    let
        locationDisplay =
            if String.length livingWageLocation.symbol > 0 then
                livingWageLocation.name ++ " (" ++ livingWageLocation.symbol ++ ")"

            else
                livingWageLocation.name
    in
    Select.item
        [ Html.Attributes.selected (form.locationId == livingWageLocation.id)
        , Html.Attributes.value (String.fromInt livingWageLocation.id)
        ]
        [ text locationDisplay ]


viewCreateStandingOrderForm : Model -> Html Msg
viewCreateStandingOrderForm model =
    Form.form [ onSubmit SubmittedStandingOrderForm ]
        [ Grid.row []
            [ Grid.col []
                [ Form.group []
                    [ Form.label [ Html.Attributes.for "email" ]
                        [ if model.creatingStandingOrder == TxOffer then
                            text "Offer to Recipient Email address"

                          else
                            text "Request From Email address"
                        ]
                    , Input.email
                        [ Input.id "email"
                        , Input.placeholder "Email"
                        , Input.onInput EnteredStandingOrderEmail
                        , Input.value model.standingOrderForm.email
                        ]
                    , Form.invalidFeedback []
                        [ if model.creatingStandingOrder == TxOffer then
                            text "Please enter recipient email address"

                          else
                            text "Please enter the email address you are requesting the standingOrder from"
                        ]
                    ]
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Form.row []
                    [ Form.col []
                        (List.map viewSuggestedTransacte (List.filter (isUserMatchingStandingOrderEmail model) (Dict.values model.txUsers)))
                    ]
                ]
            ]
        , if model.creatingStandingOrder == TxRequest then
            Grid.row []
                [ Grid.col []
                    [ Form.row []
                        [ Form.col []
                            [ Button.button
                                [ Button.secondary
                                , Button.onClick ButtonStandingOrderCheckBalance
                                , Button.disabled (String.length model.standingOrderForm.email == 0)
                                ]
                                [ text "Check balance" ]
                            ]
                        , Form.col []
                            [ text "Balance: "
                            , text (formatBalance model.creatingStandingOrderWithUser.balance)
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
                (model.creatingStandingOrderFrom == TxFromTGs)
                [ Button.primary, Button.onClick <| StandingOrderFromState TxFromTGs ]
                [ text "Direct TGs" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrderFrom == TxFromTimeMul)
                [ Button.primary, Button.onClick <| StandingOrderFromState TxFromTimeMul ]
                [ text "Time and Multiplier" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrderFrom == TxFromNational)
                [ Button.primary, Button.onClick <| StandingOrderFromState TxFromNational ]
                [ text "Equivalent to national currency" ]
            ]
        , case model.creatingStandingOrderFrom of
            TxFromTGs ->
                Grid.row []
                    [ Grid.col []
                        [ Form.group []
                            [ Form.label [ for "tgs" ] [ text "TGs (living wage hours)" ]
                            , Input.text
                                [ Input.id "tgs"
                                , Input.placeholder "TGs"
                                , Input.onInput EnteredStandingOrderTGs
                                , Input.value model.standingOrderForm.tgs
                                ]
                            , Form.invalidFeedback [] [ text "Please enter the TGs for the standingOrder" ]
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
                                , Input.onInput EnteredStandingOrderTimeH
                                , Input.value model.standingOrderForm.timeH
                                ]
                            ]
                        ]
                    , Grid.col []
                        [ Form.group []
                            [ Form.label [ for "timeM" ] [ text "Time (mm)" ]
                            , Input.text
                                [ Input.id "timeM"
                                , Input.placeholder "Minutes"
                                , Input.onInput EnteredStandingOrderTimeM
                                , Input.value model.standingOrderForm.timeM
                                ]
                            ]
                        ]
                    , Grid.col []
                        [ Form.group []
                            [ Form.label [ for "timeS" ] [ text "Time (ss)" ]
                            , Input.text
                                [ Input.id "timeS"
                                , Input.placeholder "Seconds"
                                , Input.onInput EnteredStandingOrderTimeS
                                , Input.value model.standingOrderForm.timeS
                                ]
                            ]
                        ]
                    , Grid.col []
                        [ Form.group []
                            [ Form.label [ for "multiplier" ] [ text "Multiplier" ]
                            , Input.number
                                [ Input.id "multiplier"
                                , Input.attrs [ Html.Attributes.min "1", Html.Attributes.max "3", Html.Attributes.step "0.01" ]
                                , Input.placeholder "Multiplier"
                                , Input.onInput EnteredStandingOrderMultiplier
                                , Input.value model.standingOrderForm.multiplier
                                ]
                            , Form.invalidFeedback [] [ text "Please enter the standingOrder multiplier, defaults to one" ]
                            ]
                        ]
                    ]

            TxFromNational ->
                Grid.row []
                    [ Grid.col []
                        [ Form.group []
                            [ Form.label [ for "location" ] [ text "Location" ]
                            , Select.select [ Select.id "location", Select.onChange SelectedStandingOrderLocationId ]
                                (List.concat
                                    [ List.singleton (Select.item [ Html.Attributes.value "0" ] [ text "-[Select Location]-" ])
                                    , List.map (viewSelectableLocation model.standingOrderForm) model.livingWageLocationList
                                    ]
                                )
                            ]
                        , Form.group []
                            [ Form.label [ for "national" ] [ text "National Currency" ]
                            , Input.text
                                [ Input.id "national"
                                , Input.placeholder "National"
                                , Input.disabled (model.standingOrderForm.locationId == 0)
                                , Input.onInput EnteredStandingOrderNational
                                , Input.value model.standingOrderForm.national
                                ]
                            , Form.invalidFeedback [] [ text "Please enter the National equivalent value for the standingOrder" ]
                            ]
                        ]
                    ]
        , Form.group []
            [ Form.label [ for "startDate" ] [ text "Start Date" ]
            , Input.text
                [ Input.id "startDate"
                , Input.placeholder "Start Date"
                , Input.onInput EnteredStandingOrderStartDate
                , Input.value model.standingOrderForm.startDate
                ]
            , Form.invalidFeedback [] [ text "Please enter a start date" ]
            ]
        , Form.group []
            [ Form.label [ for "stopDate" ] [ text "Stop Date" ]
            , Input.text
                [ Input.id "stopDate"
                , Input.placeholder "Stop Date"
                , Input.onInput EnteredStandingOrderStopDate
                , Input.value model.standingOrderForm.stopDate
                ]
            , Form.invalidFeedback [] [ text "Please enter a stop date" ]
            ]
        , Form.group []
            [ Form.label [ for "frequency" ] [ text "Frequency" ]
            , Html.br [] []
            , ButtonGroup.radioButtonGroup []
                [ ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyDaily)
                    [ Button.primary, Button.onClick <| SelectedStandingOrderFrequency Types.FrequencyDaily ]
                    [ text "Daily" ]
                , ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyWeekly)
                    [ Button.primary, Button.onClick <| SelectedStandingOrderFrequency Types.FrequencyWeekly ]
                    [ text "Weekly" ]
                , ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyMonthly)
                    [ Button.primary, Button.onClick <| SelectedStandingOrderFrequency Types.FrequencyMonthly ]
                    [ text "Monthly" ]
                , ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyAnnually)
                    [ Button.primary, Button.onClick <| SelectedStandingOrderFrequency Types.FrequencyAnnually ]
                    [ text "Annually" ]
                ]
            , Form.invalidFeedback [] [ text "Please select the frequency of the standing order" ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Form.group []
                    [ Form.label [] [ text "Summary - " ]
                    , text (creatingStandingOrderSummary model)
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
                        , Textarea.onInput EnteredStandingOrderDescription
                        , Textarea.value model.standingOrderForm.description
                        ]
                    , Form.invalidFeedback [] [ text "Please enter the standingOrder description" ]
                    ]
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ ul [ Html.Attributes.class "error-messages" ]
                    (List.map viewProblem model.problems)
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Button.button [ Button.primary ]
                    [ text "Submit Standing Order" ]
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading ]
            ]
        ]


standingOrderUpdateForm : (StandingOrderForm -> StandingOrderForm) -> Model -> ( Model, Cmd Msg )
standingOrderUpdateForm transform model =
    ( { model | standingOrderForm = transform model.standingOrderForm }, Cmd.none )


standingOrderValidate : StandingOrderForm -> Result (List Problem) StandingOrderTrimmedForm
standingOrderValidate form =
    let
        trimmedForm =
            standingOrderTrimFields form
    in
    case List.concatMap (validateField trimmedForm) standingOrderFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : StandingOrderTrimmedForm -> ValidatedField -> List Problem
validateField (StandingOrderTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "Email can't be blank" ]

                else if String.contains "@" form.email then
                    []

                else
                    [ "Email must contain '@'" ]

            TGs ->
                if String.isEmpty form.tgs then
                    [ "You must enter some TGs" ]

                else
                    []

            Multiplier ->
                let
                    multiplier =
                        Maybe.withDefault 0 (String.toFloat form.multiplier)
                in
                if multiplier < 1 || multiplier > 3 then
                    [ "Multiplier must be between 1 and 3" ]

                else
                    []

            _ ->
                []


type StandingOrderTrimmedForm
    = StandingOrderTrimmed StandingOrderForm


standingOrderTrimFields : StandingOrderForm -> StandingOrderTrimmedForm
standingOrderTrimFields form =
    StandingOrderTrimmed
        { email = String.trim form.email
        , startDate = form.startDate
        , stopDate = form.stopDate
        , tgs = String.trim form.tgs
        , timeH = String.trim form.timeH
        , timeM = String.trim form.timeM
        , timeS = String.trim form.timeS
        , multiplier = String.trim form.multiplier
        , locationId = form.locationId
        , national = String.trim form.national
        , description = String.trim form.description
        , txFee = String.trim form.txFee
        , frequency = form.frequency
        }



-- HTTP


standingOrder : Model -> StandingOrderTrimmedForm -> Cmd Msg
standingOrder model (StandingOrderTrimmed form) =
    let
        status =
            if model.creatingStandingOrder == TxOffer then
                1

            else
                2

        frequency =
            case form.frequency of
                Types.FrequencyDaily ->
                    1

                Types.FrequencyWeekly ->
                    2

                Types.FrequencyMonthly ->
                    3

                Types.FrequencyAnnually ->
                    4

        fromId =
            if model.creatingStandingOrder == TxOffer then
                model.loggedInUser.id

            else
                0

        toId =
            if model.creatingStandingOrder == TxOffer then
                0

            else
                model.loggedInUser.id

        seconds =
            secondsFromTgs form.tgs

        multiplier =
            Maybe.withDefault 0 (String.toFloat form.multiplier)

        txFee =
            txFeeIntFromTgs form.tgs

        timeStartDateResult =
            Iso8601.toTime form.startDate

        startTime =
            case timeStartDateResult of
                Ok time ->
                    time

                _ ->
                    model.time

        startDate =
            Time.posixToMillis startTime

        timeStopDateResult =
            Iso8601.toTime form.stopDate

        stopTime =
            case timeStopDateResult of
                Ok time ->
                    time

                _ ->
                    model.time

        stopDate =
            Time.posixToMillis stopTime

        body =
            Encode.object
                [ ( "Email", Encode.string form.email )
                , ( "StartDate", Encode.int startDate )
                , ( "StopDate", Encode.int stopDate )
                , ( "Seconds", Encode.int seconds )
                , ( "Multiplier", Encode.float multiplier )
                , ( "Status", Encode.int status )
                , ( "Frequency", Encode.int frequency )
                , ( "Description", Encode.string form.description )
                , ( "FromUserId", Encode.int fromId )
                , ( "ToUserId", Encode.int toId )
                , ( "TxFee", Encode.int txFee )
                , ( "LocationId", Encode.int form.locationId )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "/api/standing_orders"
        , expect = Http.expectJson AddedStandingOrder apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


standingOrderCheckBalance : Model -> Cmd Msg
standingOrderCheckBalance model =
    Http.request
        { method = "GET"
        , url = "/api/users?Email=" ++ model.standingOrderForm.email
        , expect = Http.expectJson LoadedStandingOrderUserWithBalance userDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
