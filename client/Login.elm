module Login exposing (LoginTrimmedForm(..), login, loginDecoder, loginFieldsToValidate, loginTrimFields, loginUpdateForm, loginValidate, pageLogin, validateField, viewLoginForm)

import FormValidation exposing (viewProblem)
import Html exposing (Html, a, button, div, fieldset, h1, input, p, text, ul)
import Html.Attributes exposing (class, href, placeholder, type_, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import Json.Decode exposing (Decoder, at, field, map2, string)
import Json.Encode as Encode
import Types exposing (LoginForm, Model, Msg(..), Problem(..), Session, ValidatedField(..))


loginFieldsToValidate : List ValidatedField
loginFieldsToValidate =
    [ Email
    , Password
    ]


loggedIn : Model -> Bool
loggedIn model =
    String.length model.session.loginToken > 0


pageLogin : Model -> List (Html Msg)
pageLogin model =
    [ div [ class "cred-page" ]
        [ div [ class "container page" ]
            [ div [ class "row" ]
                [ div [ class "col-md-6 offset-md-3 col-xs-12" ]
                    [ h1 [ class "text-xs-center" ] [ text "Login" ]
                    , p [ class "text-xs-center" ]
                        [ if loggedIn model then
                            a [ href "#logout" ]
                                [ text "Logout" ]

                          else
                            a [ href "#register" ]
                                [ text "Need an account?" ]
                        ]
                    , ul [ class "error-messages" ]
                        (List.map viewProblem model.problems)
                    , if loggedIn model then
                        text "Already logged in"

                      else
                        viewLoginForm model.loginForm
                    ]
                ]
            ]
        ]
    ]


viewLoginForm : LoginForm -> Html Msg
viewLoginForm form =
    Html.form [ onSubmit SubmittedLoginForm ]
        [ fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , placeholder "Email"
                , onInput EnteredLoginEmail
                , value form.email
                ]
                []
            , div [ class "invalid-feedback" ] [ text "Please enter your email address" ]
            ]
        , fieldset [ class "form-group" ]
            [ input
                [ class "form-control form-control-lg"
                , type_ "password"
                , placeholder "Password"
                , onInput EnteredLoginPassword
                , value form.password
                ]
                []
            , div [ class "invalid-feedback" ] [ text "Please enter your password" ]
            ]
        , button [ class "btn btn-lg btn-primary pull-xs-right" ]
            [ text "Sign in" ]
        ]


type LoginTrimmedForm
    = LoginTrimmed LoginForm


loginTrimFields : LoginForm -> LoginTrimmedForm
loginTrimFields form =
    LoginTrimmed
        { email = String.trim form.email
        , password = String.trim form.password
        }


loginUpdateForm : (LoginForm -> LoginForm) -> Model -> ( Model, Cmd Msg )
loginUpdateForm transform model =
    ( { model | loginForm = transform model.loginForm }, Cmd.none )


loginValidate : LoginForm -> Result (List Problem) LoginTrimmedForm
loginValidate form =
    let
        trimmedForm =
            loginTrimFields form
    in
    case List.concatMap (validateField trimmedForm) loginFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : LoginTrimmedForm -> ValidatedField -> List Problem
validateField (LoginTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

                else
                    []

            Password ->
                if String.isEmpty form.password then
                    [ "password can't be blank." ]

                else
                    []

            _ ->
                []



-- HTTP


login : LoginTrimmedForm -> Cmd Msg
login (LoginTrimmed form) =
    let
        body =
            Encode.object [ ( "email", Encode.string form.email ), ( "password", Encode.string form.password ) ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "http://localhost:3030/api/auth/login"
        , expect = Http.expectJson CompletedLogin loginDecoder
        , headers = []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


loginDecoder : Decoder Session
loginDecoder =
    map2 Session
        (at [ "expire" ] string)
        (at [ "token" ] string)
