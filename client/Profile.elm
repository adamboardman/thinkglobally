module Profile exposing (ProfileTrimmedForm(..), pageProfile, profile, profileFieldsToValidate, profileTrimFields, profileUpdateForm, profileValidate, updateProfileDecoder, validateField, viewProfileForm)

import FormValidation exposing (viewProblem)
import Html exposing (Html, button, div, fieldset, h1, input, text, ul)
import Html.Attributes exposing (class, placeholder, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode exposing (Decoder, at, int, map2)
import Json.Encode as Encode
import Types exposing (ApiPostResponse, Model, Msg(..), Problem(..), ProfileForm, User, ValidatedField(..), authHeader)


profileFieldsToValidate : List ValidatedField
profileFieldsToValidate =
    [ FirstName
    , MidNames
    , LastName
    , Location
    , Email
    , Mobile
    ]


pageProfile : Model -> List (Html Msg)
pageProfile model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ div [ class "col-md-6 offset-md-3 col-xs-12" ]
                [ h1 [ class "text-xs-center" ] [ text "Edit Profile" ]
                , ul [ class "error-messages" ]
                    (List.map viewProblem model.problems)
                , viewProfileForm model.profileForm
                ]
            ]
        ]
    ]


viewProfileForm : ProfileForm -> Html Msg
viewProfileForm form =
    Html.form [ onSubmit SubmittedProfileForm ]
        [ fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "First Name"
                , onInput EnteredUserFirstName
                , value form.firstName
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Mid Names"
                , onInput EnteredUserMidNames
                , value form.midNames
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Last Name"
                , onInput EnteredUserLastName
                , value form.lastName
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Location"
                , onInput EnteredUserLocation
                , value form.location
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Email"
                , onInput EnteredUserEmail
                , value form.email
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Mobile"
                , onInput EnteredUserMobile
                , value form.mobile
                ]
                []
            ]
        , button [ class "btn btn-lg btn-primary pull-xs-right" ]
            [ text "Update Profile" ]
        ]


profileUpdateForm : (ProfileForm -> ProfileForm) -> Model -> ( Model, Cmd Msg )
profileUpdateForm transform model =
    ( { model | profileForm = transform model.profileForm }, Cmd.none )


profileValidate : ProfileForm -> Result (List Problem) ProfileTrimmedForm
profileValidate form =
    let
        trimmedForm =
            profileTrimFields form
    in
    case List.concatMap (validateField trimmedForm) profileFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : ProfileTrimmedForm -> ValidatedField -> List Problem
validateField (ProfileTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            FirstName ->
                if String.isEmpty form.email then
                    [ "first name can't be blank." ]

                else
                    []

            _ ->
                []


type ProfileTrimmedForm
    = ProfileTrimmed ProfileForm


profileTrimFields : ProfileForm -> ProfileTrimmedForm
profileTrimFields form =
    ProfileTrimmed
        { id = form.id
        , firstName = String.trim form.firstName
        , midNames = String.trim form.midNames
        , lastName = String.trim form.lastName
        , email = String.trim form.email
        , location = String.trim form.location
        , mobile = String.trim form.mobile
        }



-- HTTP


profile : String -> ProfileTrimmedForm -> Cmd Msg
profile token (ProfileTrimmed form) =
    let
        body =
            Encode.object
                [ ( "FirstName", Encode.string form.firstName )
                , ( "MidNames", Encode.string form.midNames )
                , ( "LastName", Encode.string form.lastName )
                , ( "Email", Encode.string form.email )
                , ( "Location", Encode.string form.location )
                , ( "Mobile", Encode.string form.mobile )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "PUT"
        , url = "http://localhost:3030/api/users/" ++ String.fromInt form.id
        , expect = Http.expectJson GotUpdateProfileJson updateProfileDecoder
        , headers = [ authHeader token ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


updateProfileDecoder : Decoder ApiPostResponse
updateProfileDecoder =
    map2 ApiPostResponse
        (at [ "status" ] int)
        (at [ "resourceId" ] int)
