module Main exposing (main)

import Bootstrap.Button as Button
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (class, href, placeholder, type_, value)
import Http exposing (Error(..))
import Json.Decode as Decode exposing (Decoder, decodeString, field, string)
import Login exposing (login, loginUpdateForm, loginValidate, pageLogin)
import Register exposing (pageRegister, register, registerUpdateForm, registerValidate)
import Types exposing (LoginForm, Model, Msg(..), Page(..), Problem(..))
import Url exposing (Url)
import Url.Parser as UrlParser exposing ((</>), Parser, s, top)



-- TYPES


type alias Flags =
    {}



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( navState, navCmd ) =
            Navbar.initialState NavMsg

        ( model, urlCmd ) =
            urlUpdate url
                { navKey = key
                , navState = navState
                , page = Home
                , modalVisibility = Modal.hidden
                , problems = []
                , loginForm = { email = "", password = "" }
                , registerForm = { email = "", password = "", password_confirm = "" }
                , session = { loginExpire = "", loginToken = "" }
                , postResponse = { status = 0, resourceId = 0 }
                }
    in
    ( model, Cmd.batch [ urlCmd, navCmd ] )


view : Model -> Document Msg
view model =
    { title = "Think Globally - Trade Locally"
    , body =
        [ div []
            [ menu model
            , mainContent model
            , modal model
            ]
        ]
    }


menu : Model -> Html Msg
menu model =
    Navbar.config NavMsg
        |> Navbar.withAnimation
        |> Navbar.container
        |> Navbar.brand [ href "#" ] [ text "ThinkGlobally" ]
        |> Navbar.items
            [ Navbar.itemLink [ href "#login" ] [ text "Sign in" ]
            ]
        |> Navbar.view model.navState


mainContent : Model -> Html Msg
mainContent model =
    Grid.container [] <|
        case model.page of
            Home ->
                pageHome model

            Login ->
                pageLogin model

            Register ->
                pageRegister model

            NotFound ->
                pageNotFound


pageHome : Model -> List (Html Msg)
pageHome model =
    [ text "TG's"
    ]


pageNotFound : List (Html Msg)
pageNotFound =
    [ h1 [] [ text "Not found" ]
    , text "Sorry couldn't find that page"
    ]


modal : Model -> Html Msg
modal model =
    Modal.config CloseModal
        |> Modal.small
        |> Modal.h4 [] [ text "TGs" ]
        |> Modal.body []
            [ Grid.containerFluid []
                [ Grid.row []
                    [ Grid.col
                        [ Col.xs6 ]
                        [ text "Col 1" ]
                    , Grid.col
                        [ Col.xs6 ]
                        [ text "Col 2" ]
                    ]
                ]
            ]
        |> Modal.view model.modalVisibility



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedLink urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( { model
                        | problems = []
                        , loginForm = { email = "", password = "" }
                        , registerForm = { email = "", password = "", password_confirm = "" }
                        , postResponse = { status = 0, resourceId = 0 }
                      }
                    , Nav.pushUrl model.navKey (Url.toString url)
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        ChangedUrl url ->
            urlUpdate url model

        NavMsg state ->
            ( { model | navState = state }, Cmd.none )

        CloseModal ->
            ( { model | modalVisibility = Modal.hidden }, Cmd.none )

        ShowModal ->
            ( { model | modalVisibility = Modal.shown }, Cmd.none )

        SubmittedLoginForm ->
            case loginValidate model.loginForm of
                Ok validForm ->
                    ( { model | problems = [] }
                    , login validForm
                    )

                Err problems ->
                    ( { model | problems = problems }
                    , Cmd.none
                    )

        SubmittedRegisterForm ->
            case registerValidate model.registerForm of
                Ok validForm ->
                    ( { model | problems = [] }
                    , register validForm
                    )

                Err problems ->
                    ( { model | problems = problems }
                    , Cmd.none
                    )

        EnteredLoginEmail email ->
            loginUpdateForm (\form -> { form | email = email }) model

        EnteredRegisterEmail email ->
            registerUpdateForm (\form -> { form | email = email }) model

        EnteredLoginPassword password ->
            loginUpdateForm (\form -> { form | password = password }) model

        EnteredRegisterPassword password ->
            registerUpdateForm (\form -> { form | password = password }) model

        EnteredRegisterConfirmPassword password_confirm ->
            registerUpdateForm (\form -> { form | password_confirm = password_confirm }) model

        CompletedLogin (Err error) ->
            let
                serverErrors =
                    decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors }
            , Cmd.none
            )

        CompletedLogin (Ok res) ->
            ( { model | session = res }
            , Cmd.none
            )

        GotRegisterJson result ->
            case result of
                Ok res ->
                    ( { model | postResponse = res }, Cmd.none )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors }, Cmd.none )


decodeErrors : Http.Error -> List String
decodeErrors error =
    case error of
        Timeout ->
            [ "Timeout exceeded" ]

        NetworkError ->
            [ "Network error" ]

        BadBody body ->
            [ body ]

        BadUrl url ->
            [ "Malformed url: " ++ url ]

        err ->
            [ "Server error" ]


errorsDecoder : Decoder (List String)
errorsDecoder =
    Decode.keyValuePairs (Decode.list Decode.string)
        |> Decode.map (List.concatMap fromPair)


fromPair : ( String, List String ) -> List String
fromPair ( field, errors ) =
    List.map (\error -> field ++ " " ++ error) errors


urlUpdate : Url -> Model -> ( Model, Cmd Msg )
urlUpdate url model =
    case decode url of
        Nothing ->
            ( { model | page = NotFound }, Cmd.none )

        Just route ->
            ( { model | page = route }, Cmd.none )


decode : Url -> Maybe Page
decode url =
    { url | path = Maybe.withDefault "" url.fragment, fragment = Nothing }
        |> UrlParser.parse routeParser


routeParser : Parser (Page -> a) a
routeParser =
    UrlParser.oneOf
        [ UrlParser.map Home top
        , UrlParser.map Login (s "login")
        , UrlParser.map Register (s "register")
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Navbar.subscriptions model.navState NavMsg
