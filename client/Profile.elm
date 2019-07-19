module Profile exposing (ProfileTrimmedForm(..), pageProfile, profile, profileFieldsToValidate, profileTrimFields, profileUpdateForm, profileValidate, updateProfileDecoder, validateField, viewProfileForm)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup exposing (Input)
import FormValidation exposing (viewProblem)
import Html exposing (Html, button, div, fieldset, h1, input, text, ul)
import Html.Attributes exposing (class, for, placeholder, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode exposing (Decoder, at, int, map2)
import Json.Encode as Encode
import Loading
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
                , viewProfileForm model
                ]
            ]
        ]
    ]


viewProfileForm : Model -> Html Msg
viewProfileForm model =
    Form.form [ onSubmit SubmittedProfileForm ]
        [ Form.group []
            [ Form.label [ for "firstName" ] [ text "First Name" ]
            , Input.text
                [ Input.id "firstName"
                , Input.placeholder "First Name"
                , Input.onInput EnteredUserFirstName
                , Input.value model.profileForm.firstName
                ]
            , Form.invalidFeedback [] [ text "Please enter your first or given name" ]
            ]
        , Form.group []
            [ Form.label [ for "midNames" ] [ text "Mid Names" ]
            , Input.text
                [ Input.id "midNames"
                , Input.placeholder "Mid Names"
                , Input.onInput EnteredUserMidNames
                , Input.value model.profileForm.midNames
                ]
            , Form.invalidFeedback [] [ text "Please enter your middle names" ]
            ]
        , Form.group []
            [ Form.label [ for "lastName" ] [ text "Last Name" ]
            , Input.text
                [ Input.id "lastName"
                , Input.placeholder "Last Name"
                , Input.onInput EnteredUserLastName
                , Input.value model.profileForm.lastName
                ]
            , Form.invalidFeedback [] [ text "Please enter your last name or surname" ]
            ]
        , Form.group []
            [ Form.label [ for "location" ] [ text "Location" ]
            , Input.text
                [ Input.id "location"
                , Input.placeholder "Location"
                , Input.onInput EnteredUserLocation
                , Input.value model.profileForm.location
                ]
            , Form.invalidFeedback [] [ text "Home location for display on your profile" ]
            ]
        , Form.group []
            [ Form.label [ for "email" ] [ text "Email" ]
            , Input.text
                [ Input.id "email"
                , Input.placeholder "Email"
                , Input.onInput EnteredUserEmail
                , Input.value model.profileForm.email
                ]
            , Form.invalidFeedback [] [ text "Please enter your email" ]
            ]
        , Form.group []
            [ Form.label [ for "mobile" ] [ text "Mobile" ]
            , Input.text
                [ Input.id "mobile"
                , Input.placeholder "Mobile"
                , Input.onInput EnteredUserMobile
                , Input.value model.profileForm.mobile
                ]
            , Form.invalidFeedback [] [ text "Please enter your mobile" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Update Profile" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading
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
                if String.isEmpty form.firstName then
                    [ "first name can't be blank." ]

                else
                    []

            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

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
