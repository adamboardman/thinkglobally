module LivingWageLocationEdit exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import FormValidation exposing (viewProblem)
import Html exposing (Html, div, h1, text, ul)
import Html.Attributes exposing (class, for)
import Html.Events exposing (onSubmit)
import Http
import Json.Encode as Encode exposing (Value)
import Loading
import Markdown
import Types exposing (ApiActionResponse, ConceptForm, ConceptTag, ConceptTagForm, LivingWageLocationForm, Model, Msg(..), Problem(..), Tag, ValidatedField(..), apiActionDecoder, authHeader)


pageLivingWageLocationEdit : Model -> List (Html Msg)
pageLivingWageLocationEdit model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ if model.loading == Loading.Off && model.livingWageLocation.id > 0 then
                div [ class "col-12" ]
                    [ h1 [ class "text-xs-center" ] [ text "Existing Living Wage Location" ]
                    , div [] <| Markdown.toHtml Nothing model.livingWageLocation.name
                    , h1 [ class "text-xs-center" ] [ text "Edit Living Wage Location" ]
                    , viewLivingWageLocationForm model
                    ]

              else if model.loading == Loading.Off then
                div [ class "col-12" ]
                    [ h1 [ class "text-xs-center" ] [ text "Loading Living Wage Location Failed" ]
                    ]

              else
                div [ class "col-12" ] [ h1 [ class "text-xs-center" ] [ text "Loading Living Wage Location" ] ]
            ]
        ]
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]


pageAddLivingWageLocation : Model -> List (Html Msg)
pageAddLivingWageLocation model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ div [ class "col-12" ]
                [ h1 [ class "text-xs-center" ] [ text "Add Living Wage Location" ]
                , viewLivingWageLocationForm model
                ]
            ]
        ]
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]


viewLivingWageLocationForm : Model -> Html Msg
viewLivingWageLocationForm model =
    Form.form [ onSubmit SubmittedLivingWageLocationForm ]
        [ Form.group []
            [ Form.label [ for "name" ] [ text "Living Wage Location Name" ]
            , Input.text
                [ Input.id "name"
                , Input.placeholder "Living Wage Location Name"
                , Input.onInput EnteredLivingWageLocationName
                , Input.value model.livingWageLocationForm.name
                ]
            , Form.invalidFeedback [] [ text "Please enter a name" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Save Living Wage Location" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading
        ]


livingWageLocationFieldsToValidate : List ValidatedField
livingWageLocationFieldsToValidate =
    [ Name ]


type LivingWageLocationTrimmedForm
    = LivingWageLocationTrimmed LivingWageLocationForm


livingWageLocationTrimFields : LivingWageLocationForm -> LivingWageLocationTrimmedForm
livingWageLocationTrimFields form =
    LivingWageLocationTrimmed
        { name = String.trim form.name }


validateField : LivingWageLocationTrimmedForm -> ValidatedField -> List Problem
validateField (LivingWageLocationTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Name ->
                if String.isEmpty form.name then
                    [ "name can't be blank." ]

                else
                    []

            _ ->
                []


livingWageLocationValidate : LivingWageLocationForm -> Result (List Problem) LivingWageLocationTrimmedForm
livingWageLocationValidate form =
    let
        trimmedForm =
            livingWageLocationTrimFields form
    in
    case List.concatMap (validateField trimmedForm) livingWageLocationFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


livingWageLocationUpdateForm : (LivingWageLocationForm -> LivingWageLocationForm) -> Model -> ( Model, Cmd Msg )
livingWageLocationUpdateForm transform model =
    ( { model | livingWageLocationForm = transform model.livingWageLocationForm }, Cmd.none )



-- HTTP


livingWageLocationUpdate : Model -> LivingWageLocationTrimmedForm -> Cmd Msg
livingWageLocationUpdate model (LivingWageLocationTrimmed form) =
    let
        body =
            Encode.object
                [ ( "Id", Encode.int model.livingWageLocation.id )
                , ( "Name", Encode.string form.name )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "PUT"
        , url = "/api/living_wage_locations/" ++ String.fromInt model.livingWageLocation.id
        , expect = Http.expectJson AddedLivingWageLocation apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


livingWageLocationAdd : Model -> LivingWageLocationTrimmedForm -> Cmd Msg
livingWageLocationAdd model (LivingWageLocationTrimmed form) =
    let
        body =
            Encode.object
                [ ( "Id", Encode.int model.livingWageLocation.id )
                , ( "Name", Encode.string form.name )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "/api/living_wage_locations"
        , expect = Http.expectJson AddedLivingWageLocation apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }
