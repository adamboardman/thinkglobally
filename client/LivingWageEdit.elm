module LivingWageEdit exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Select as Select
import FormValidation exposing (viewProblem)
import FormatNumber exposing (format)
import Html exposing (Html, div, h1, text, ul)
import Html.Attributes exposing (class, for)
import Html.Events exposing (onSubmit)
import Http
import Iso8601
import Json.Encode as Encode exposing (Value)
import Loading
import Time exposing (Weekday(..))
import Types exposing (ApiActionResponse, ConceptForm, ConceptTag, ConceptTagForm, LivingWage, LivingWageForm, LivingWageLocation, Model, Msg(..), Problem(..), Tag, ValidatedField(..), apiActionDecoder, authHeader, formatDate, nationalLocale)


pageLivingWageEdit : Model -> List (Html Msg)
pageLivingWageEdit model =
    let
        location =
            Maybe.withDefault Types.emptyLivingWageLocation (List.head (List.filter (\lwl -> model.livingWage.locationId == lwl.id) model.livingWageLocationList))
    in
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ if model.loading == Loading.Off && model.livingWage.id > 0 then
                div [ class "col-12" ]
                    [ h1 [ class "text-xs-center" ] [ text "Existing Living Wage" ]
                    , Html.div [] [ text "Start Date: ", text (formatDate model model.livingWage.startDate) ]
                    , Html.div [] [ text "Stop Date: ", text (formatDate model model.livingWage.stopDate) ]
                    , Html.div []
                        [ text "Location: "
                        , text location.name
                        ]
                    , Html.div [] [ text "Wage: ", text location.symbol, text (format nationalLocale model.livingWage.wage) ]
                    , h1 [ class "text-xs-center" ] [ text "Edit Living Wage" ]
                    , viewLivingWageForm model
                    ]

              else if model.loading == Loading.Off then
                div [ class "col-12" ]
                    [ h1 [ class "text-xs-center" ] [ text "Loading Living Wage Failed" ]
                    ]

              else
                div [ class "col-12" ] [ h1 [ class "text-xs-center" ] [ text "Loading Living Wage" ] ]
            ]
        ]
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]


pageAddLivingWage : Model -> List (Html Msg)
pageAddLivingWage model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ div [ class "col-12" ]
                [ h1 [ class "text-xs-center" ] [ text "Add Living Wage" ]
                , viewLivingWageForm model
                ]
            ]
        ]
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]


viewSelectableLocation : LivingWageForm -> LivingWageLocation -> Select.Item Msg
viewSelectableLocation form livingWageLocation =
    Select.item [ Html.Attributes.selected (form.locationId == livingWageLocation.id), Html.Attributes.value (String.fromInt livingWageLocation.id) ] [ text livingWageLocation.name ]


viewLivingWageForm : Model -> Html Msg
viewLivingWageForm model =
    Form.form [ onSubmit SubmittedLivingWageForm ]
        [ Form.group []
            [ Form.label [ for "startDate" ] [ text "Start Date" ]
            , Input.text
                [ Input.id "startDate"
                , Input.placeholder "Start Date"
                , Input.onInput EnteredLivingWageStartDate
                , Input.value model.livingWageForm.startDate
                ]
            , Form.invalidFeedback [] [ text "Please enter a start date" ]
            ]
        , Form.group []
            [ Form.label [ for "stopDate" ] [ text "Stop Date" ]
            , Input.text
                [ Input.id "stopDate"
                , Input.placeholder "Stop Date"
                , Input.onInput EnteredLivingWageStopDate
                , Input.value model.livingWageForm.stopDate
                ]
            , Form.invalidFeedback [] [ text "Please enter a stop date" ]
            ]
        , Form.group []
            [ Form.label [ for "location" ] [ text "Location" ]
            , Select.select
                [ Select.id "location"
                , Select.onChange SelectedLocationId
                ]
                (List.concat
                    [ List.singleton (Select.item [ Html.Attributes.value "0" ] [ text "-[Select Location]-" ])
                    , List.map (viewSelectableLocation model.livingWageForm) model.livingWageLocationList
                    ]
                )
            ]
        , Form.group []
            [ Form.label [ for "wage" ] [ text "Living Wage per Hour" ]
            , Input.text
                [ Input.id "wage"
                , Input.placeholder "Living Wage Wage"
                , Input.onInput EnteredLivingWageWage
                , Input.value model.livingWageForm.wage
                ]
            , Form.invalidFeedback [] [ text "Please enter a wage" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Save Living Wage" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading
        ]


livingWageFieldsToValidate : List ValidatedField
livingWageFieldsToValidate =
    [ Location
    , StartDate
    , StopDate
    ]


type LivingWageTrimmedForm
    = LivingWageTrimmed LivingWageForm


livingWageTrimFields : LivingWageForm -> LivingWageTrimmedForm
livingWageTrimFields form =
    LivingWageTrimmed
        { startDate = form.startDate
        , stopDate = form.stopDate
        , locationId = form.locationId
        , wage = form.wage
        }


validateField : LivingWageTrimmedForm -> ValidatedField -> List Problem
validateField (LivingWageTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Location ->
                if form.locationId == 0 then
                    [ "you must select a location" ]

                else
                    []

            StartDate ->
                []

            StopDate ->
                []

            _ ->
                []


livingWageValidate : LivingWageForm -> Result (List Problem) LivingWageTrimmedForm
livingWageValidate form =
    let
        trimmedForm =
            livingWageTrimFields form
    in
    case List.concatMap (validateField trimmedForm) livingWageFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


livingWageUpdateForm : (LivingWageForm -> LivingWageForm) -> Model -> ( Model, Cmd Msg )
livingWageUpdateForm transform model =
    ( { model | livingWageForm = transform model.livingWageForm }, Cmd.none )



-- HTTP


livingWageBody : Model -> LivingWageForm -> Http.Body
livingWageBody model form =
    let
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

        wageFloat =
            Maybe.withDefault 0.0 (String.toFloat form.wage)
    in
    Encode.object
        [ ( "Id", Encode.int model.livingWage.id )
        , ( "StartDate", Encode.int startDate )
        , ( "StopDate", Encode.int stopDate )
        , ( "LocationId", Encode.int form.locationId )
        , ( "Wage", Encode.float wageFloat )
        ]
        |> Http.jsonBody


livingWageUpdate : Model -> LivingWageTrimmedForm -> Cmd Msg
livingWageUpdate model (LivingWageTrimmed form) =
    let
        body =
            livingWageBody model form
    in
    Http.request
        { method = "PUT"
        , url = "/api/living_wages/" ++ String.fromInt model.livingWage.id
        , expect = Http.expectJson AddedLivingWage apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


livingWageAdd : Model -> LivingWageTrimmedForm -> Cmd Msg
livingWageAdd model (LivingWageTrimmed form) =
    let
        body =
            livingWageBody model form
    in
    Http.request
        { method = "POST"
        , url = "/api/living_wages"
        , expect = Http.expectJson AddedLivingWage apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }
