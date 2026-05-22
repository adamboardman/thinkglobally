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
import Types exposing (Model, Msg)


standingOrderFieldsToValidate : List Types.ValidatedField
standingOrderFieldsToValidate =
    [ Types.Email
    , Types.StartDate
    , Types.TGs
    , Types.Multiplier
    ]


pageStandingOrderCreate : Model -> List (Html Msg)
pageStandingOrderCreate model =
    [ h4 [] [ text "Create StandingOrder" ]
    , Grid.container []
        [ ButtonGroup.radioButtonGroup []
            [ ButtonGroup.radioButton
                (model.creatingStandingOrder == Types.TxNone)
                [ Button.primary, Button.onClick <| Types.StandingOrderState Types.TxNone ]
                [ text "Hidden" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrder == Types.TxOffer)
                [ Button.primary, Button.onClick <| Types.StandingOrderState Types.TxOffer ]
                [ text "Offer" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrder == Types.TxRequest)
                [ Button.primary, Button.onClick <| Types.StandingOrderState Types.TxRequest ]
                [ text "Request" ]
            ]
        , if model.creatingStandingOrder == Types.TxNone then
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


isUserMatchingStandingOrderEmail : Model -> Types.User -> Bool
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


viewSuggestedTransacte : Types.User -> Html Msg
viewSuggestedTransacte user =
    Button.button [ Button.secondary, Button.onClick <| Types.EnteredStandingOrderEmail user.email ] [ text (String.concat [ user.firstName, " ", user.midNames, " ", user.lastName, " (", user.email, ")", " " ]) ]


viewSelectableLocation : Types.StandingOrderForm -> Types.LivingWageLocation -> Select.Item Msg
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
    Form.form [ onSubmit Types.SubmittedStandingOrderForm ]
        [ Grid.row []
            [ Grid.col []
                [ Form.group []
                    [ Form.label [ Html.Attributes.for "email" ]
                        [ if model.creatingStandingOrder == Types.TxOffer then
                            text "Offer to Recipient Email address"

                          else
                            text "Request From Email address"
                        ]
                    , Input.email
                        [ Input.id "email"
                        , Input.placeholder "Email"
                        , Input.onInput Types.EnteredStandingOrderEmail
                        , Input.value model.standingOrderForm.email
                        ]
                    , Form.invalidFeedback []
                        [ if model.creatingStandingOrder == Types.TxOffer then
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
        , if model.creatingStandingOrder == Types.TxRequest then
            Grid.row []
                [ Grid.col []
                    [ Form.row []
                        [ Form.col []
                            [ Button.button
                                [ Button.secondary
                                , Button.onClick Types.ButtonStandingOrderCheckBalance
                                , Button.disabled (String.length model.standingOrderForm.email == 0)
                                ]
                                [ text "Check balance" ]
                            ]
                        , Form.col []
                            [ text "Balance: "
                            , text (Types.formatBalance model.creatingStandingOrderWithUser.balance)
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
                            , text (Types.formatBalance model.loggedInUser.balance)
                            ]
                        ]
                    ]
                ]
        , ButtonGroup.radioButtonGroup []
            [ ButtonGroup.radioButton
                (model.creatingStandingOrderFrom == Types.TxFromTGs)
                [ Button.primary, Button.onClick <| Types.StandingOrderFromState Types.TxFromTGs ]
                [ text "Direct TGs" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrderFrom == Types.TxFromTimeMul)
                [ Button.primary, Button.onClick <| Types.StandingOrderFromState Types.TxFromTimeMul ]
                [ text "Time and Multiplier" ]
            , ButtonGroup.radioButton
                (model.creatingStandingOrderFrom == Types.TxFromNational)
                [ Button.primary, Button.onClick <| Types.StandingOrderFromState Types.TxFromNational ]
                [ text "Equivalent to national currency" ]
            ]
        , case model.creatingStandingOrderFrom of
            Types.TxFromTGs ->
                Grid.row []
                    [ Grid.col []
                        [ Form.group []
                            [ Form.label [ for "tgs" ] [ text "TGs (living wage hours)" ]
                            , Input.text
                                [ Input.id "tgs"
                                , Input.placeholder "TGs"
                                , Input.onInput Types.EnteredStandingOrderTGs
                                , Input.value model.standingOrderForm.tgs
                                ]
                            , Form.invalidFeedback [] [ text "Please enter the TGs for the standingOrder" ]
                            ]
                        ]
                    ]

            Types.TxFromTimeMul ->
                Grid.row []
                    [ Grid.col []
                        [ Form.group []
                            [ Form.label [ for "timeH" ] [ text "Time (HH)" ]
                            , Input.text
                                [ Input.id "timeH"
                                , Input.placeholder "Hours"
                                , Input.onInput Types.EnteredStandingOrderTimeH
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
                                , Input.onInput Types.EnteredStandingOrderTimeM
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
                                , Input.onInput Types.EnteredStandingOrderTimeS
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
                                , Input.onInput Types.EnteredStandingOrderMultiplier
                                , Input.value model.standingOrderForm.multiplier
                                ]
                            , Form.invalidFeedback [] [ text "Please enter the standingOrder multiplier, defaults to one" ]
                            ]
                        ]
                    ]

            Types.TxFromNational ->
                Grid.row []
                    [ Grid.col []
                        [ Form.group []
                            [ Form.label [ for "location" ] [ text "Location" ]
                            , Select.select [ Select.id "location", Select.onChange Types.SelectedStandingOrderLocationId ]
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
                                , Input.onInput Types.EnteredStandingOrderNational
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
                , Input.onInput Types.EnteredStandingOrderStartDate
                , Input.value model.standingOrderForm.startDate
                ]
            , Form.invalidFeedback [] [ text "Please enter a start date" ]
            ]
        , Form.group []
            [ Form.label [ for "stopDate" ] [ text "Stop Date" ]
            , Input.text
                [ Input.id "stopDate"
                , Input.placeholder "Stop Date"
                , Input.onInput Types.EnteredStandingOrderStopDate
                , Input.value model.standingOrderForm.stopDate
                ]
            , Form.invalidFeedback [] [ text "Please enter a stop date - leave blank for never ending" ]
            ]
        , Form.group []
            [ Form.label [ for "frequency" ] [ text "Frequency" ]
            , Html.br [] []
            , ButtonGroup.radioButtonGroup []
                [ ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyDaily)
                    [ Button.primary, Button.onClick <| Types.SelectedStandingOrderFrequency Types.FrequencyDaily ]
                    [ text "Daily" ]
                , ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyWeekly)
                    [ Button.primary, Button.onClick <| Types.SelectedStandingOrderFrequency Types.FrequencyWeekly ]
                    [ text "Weekly" ]
                , ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyMonthly)
                    [ Button.primary, Button.onClick <| Types.SelectedStandingOrderFrequency Types.FrequencyMonthly ]
                    [ text "Monthly" ]
                , ButtonGroup.radioButton
                    (model.standingOrderForm.frequency == Types.FrequencyAnnually)
                    [ Button.primary, Button.onClick <| Types.SelectedStandingOrderFrequency Types.FrequencyAnnually ]
                    [ text "Annually" ]
                ]
            , Form.invalidFeedback [] [ text "Please select the frequency of the standing order" ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Form.group []
                    [ Form.label [] [ text "Summary - " ]
                    , text (Types.creatingStandingOrderSummary model)
                    , Html.br [] []
                    , text (Types.creatingStandingOrderWarning model)
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
                        , Textarea.onInput Types.EnteredStandingOrderDescription
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


standingOrderUpdateForm : (Types.StandingOrderForm -> Types.StandingOrderForm) -> Model -> ( Model, Cmd Msg )
standingOrderUpdateForm transform model =
    ( { model | standingOrderForm = transform model.standingOrderForm }, Cmd.none )


standingOrderValidate : Types.StandingOrderForm -> Result (List Types.Problem) StandingOrderTrimmedForm
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


validateField : StandingOrderTrimmedForm -> Types.ValidatedField -> List Types.Problem
validateField (StandingOrderTrimmed form) field =
    List.map (Types.InvalidEntry field) <|
        case field of
            Types.StartDate ->
                if String.isEmpty form.startDate then
                    [ "Start Date can't be blank" ]

                else
                    []

            Types.Email ->
                if String.isEmpty form.email then
                    [ "Email can't be blank" ]

                else if String.contains "@" form.email then
                    []

                else
                    [ "Email must contain '@'" ]

            Types.TGs ->
                if String.isEmpty form.tgs then
                    [ "You must enter some TGs" ]

                else
                    []

            Types.Multiplier ->
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
    = StandingOrderTrimmed Types.StandingOrderForm


standingOrderTrimFields : Types.StandingOrderForm -> StandingOrderTrimmedForm
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
            if model.creatingStandingOrder == Types.TxOffer then
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
            if model.creatingStandingOrder == Types.TxOffer then
                model.loggedInUser.id

            else
                0

        toId =
            if model.creatingStandingOrder == Types.TxOffer then
                0

            else
                model.loggedInUser.id

        seconds =
            Types.secondsFromTgs form.tgs

        multiplier =
            Maybe.withDefault 0 (String.toFloat form.multiplier)

        txFee =
            Types.txFeeIntFromTgs form.tgs

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
                    Time.millisToPosix 0

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
        , expect = Http.expectJson Types.AddedStandingOrder Types.apiActionDecoder
        , headers = [ Types.authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


standingOrderCheckBalance : Model -> Cmd Msg
standingOrderCheckBalance model =
    Http.request
        { method = "GET"
        , url = "/api/users?Email=" ++ model.standingOrderForm.email
        , expect = Http.expectJson Types.LoadedStandingOrderUserWithBalance Types.userDecoder
        , headers = [ Types.authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
