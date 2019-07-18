module Register exposing (RegisterTrimmedForm(..), pageRegister, register, registerDecoder, registerFieldsToValidate, registerTrimFields, registerUpdateForm, registerValidate, validateField, viewRegisterForm)

import FormValidation exposing (viewProblem)
import Html exposing (Html, a, button, div, fieldset, h1, input, p, text, ul)
import Html.Attributes exposing (class, href, placeholder, type_, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode exposing (Decoder, at, field, int, map2, string)
import Json.Encode as Encode
import Types exposing (ApiPostResponse, LoginForm, Model, Msg(..), Problem(..), RegisterForm, Session, ValidatedField(..))


registerFieldsToValidate : List ValidatedField
registerFieldsToValidate =
    [ Email
    , Password
    , ConfirmPassword
    ]


pageRegister : Model -> List (Html Msg)
pageRegister model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ div [ class "col-md-6 offset-md-3 col-xs-12" ]
                [ h1 [ class "text-xs-center" ] [ text "Register" ]
                , p [ class "text-xs-center" ]
                    [ a [ href "#login" ]
                        [ text "Have an account?" ]
                    ]
                , ul [ class "error-messages" ]
                    (List.map viewProblem model.problems)
                , if model.postResponse.resourceId == 0 then
                    viewRegisterForm model.registerForm

                  else
                    text "Please check your email (inc spam folder) and click the confirmation link"
                ]
            ]
        ]
    ]


viewRegisterForm : RegisterForm -> Html Msg
viewRegisterForm form =
    Html.form [ onSubmit SubmittedRegisterForm ]
        [ fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Email"
                , onInput EnteredRegisterEmail
                , value form.email
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , type_ "password"
                , placeholder "Password"
                , onInput EnteredRegisterPassword
                , value form.password
                ]
                []
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , type_ "password"
                , placeholder "Confirm your password"
                , onInput EnteredRegisterConfirmPassword
                , value form.password_confirm
                ]
                []
            ]
        , button [ class "btn btn-lg btn-primary pull-xs-right" ]
            [ text "Register" ]
        ]


registerUpdateForm : (RegisterForm -> RegisterForm) -> Model -> ( Model, Cmd Msg )
registerUpdateForm transform model =
    ( { model | registerForm = transform model.registerForm }, Cmd.none )


registerValidate : RegisterForm -> Result (List Problem) RegisterTrimmedForm
registerValidate form =
    let
        trimmedForm =
            registerTrimFields form
    in
    case List.concatMap (validateField trimmedForm) registerFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : RegisterTrimmedForm -> ValidatedField -> List Problem
validateField (RegisterTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

                else if String.contains form.email "@" then
                    []

                else
                    [ "email must contain '@'" ]

            Password ->
                if String.isEmpty form.password then
                    [ "password can't be blank." ]

                else if form.password == form.password_confirm then
                    []

                else
                    [ "Passwords must match" ]

            ConfirmPassword ->
                if String.isEmpty form.password then
                    [ "confirm password can't be blank." ]

                else if form.password == form.password_confirm then
                    []

                else
                    [ "Passwords must match" ]

            _ ->
                []


type RegisterTrimmedForm
    = RegisterTrimmed RegisterForm


registerTrimFields : RegisterForm -> RegisterTrimmedForm
registerTrimFields form =
    RegisterTrimmed
        { email = String.trim form.email
        , password = String.trim form.password
        , password_confirm = String.trim form.password_confirm
        }



-- HTTP


register : RegisterTrimmedForm -> Cmd Msg
register (RegisterTrimmed form) =
    let
        body =
            Encode.object
                [ ( "email", Encode.string form.email )
                , ( "password", Encode.string form.password )
                , ( "password_confirmation", Encode.string form.password_confirm )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "http://localhost:3030/api/auth/register"
        , expect = Http.expectJson GotRegisterJson registerDecoder
        , headers = []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


registerDecoder : Decoder ApiPostResponse
registerDecoder =
    map2 ApiPostResponse
        (at [ "status" ] int)
        (at [ "resourceId" ] int)
