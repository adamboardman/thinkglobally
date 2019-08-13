module Main exposing (main)

import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Concept exposing (pageConcept)
import Dict
import Html exposing (..)
import Html.Attributes exposing (href)
import Http exposing (Error(..), emptyBody)
import Json.Decode as Decode exposing (Decoder, field)
import Loading
import Login exposing (loggedIn, login, loginUpdateForm, loginValidate, pageLogin, userIsEditor)
import Profile exposing (pageProfile, profile, profileUpdateForm, profileValidate)
import Register exposing (pageRegister, register, registerUpdateForm, registerValidate)
import Task
import Time
import Transaction exposing (acceptTransaction, loadTransactions, loadTxUsers, pageTransaction, rejectTransaction, transaction, transactionUpdateForm, transactionValidate)
import Types exposing (LoginForm, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionType(..), User, authHeader, conceptDecoder, indexUser, profileDecoder, tgsFromTimeAndMultiplier, timeFromTgs, userDecoder)
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
                , loading = Loading.Off
                , modalVisibility = Modal.hidden
                , problems = []
                , loginForm = { email = "", password = "" }
                , registerForm = { email = "", password = "", password_confirm = "" }
                , session = { loginExpire = "", loginToken = "" }
                , apiActionResponse = { status = 0, resourceId = 0 }
                , loggedInUser =
                    { id = 0
                    , firstName = ""
                    , midNames = ""
                    , lastName = ""
                    , location = ""
                    , email = ""
                    , mobile = ""
                    , permissions = 0
                    }
                , profileForm =
                    { id = 0
                    , firstName = ""
                    , midNames = ""
                    , lastName = ""
                    , location = ""
                    , email = ""
                    , mobile = ""
                    }
                , transactionForm =
                    { email = ""
                    , tgs = ""
                    , time = ""
                    , multiplier = "1"
                    }
                , concept =
                    { id = 0
                    , name = ""
                    , summary = ""
                    , full = ""
                    , tags = []
                    }
                , creatingTransaction = TxNone
                , transactions = []
                , pendingTransactions = []
                , txUsers = Dict.empty
                , timeZone = Time.utc
                , time = Time.millisToPosix 0
                }
    in
    ( model
    , Cmd.batch
        [ urlCmd
        , navCmd
        , Task.perform AdjustTimeZone Time.here
        , Task.perform TimeTick Time.now
        ]
    )


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
            [ if userIsEditor model then
                Navbar.itemLink [ href "#concepts" ] [ text "Concepts" ]

              else
                Navbar.itemLink [ href "" ] [ text "" ]
            , if loggedIn model then
                Navbar.itemLink [ href "#profile" ] [ text "Profile" ]

              else
                Navbar.itemLink [ href "" ] [ text "" ]
            , if loggedIn model then
                Navbar.itemLink [ href "#transaction" ] [ text "Transactions" ]

              else
                Navbar.itemLink [ href "" ] [ text "" ]
            , if loggedIn model then
                Navbar.itemLink [ href "#logout" ] [ text "Logout" ]

              else
                Navbar.itemLink [ href "#login" ] [ text "Login" ]
            ]
        |> Navbar.view model.navState


mainContent : Model -> Html Msg
mainContent model =
    Grid.container [] <|
        case model.page of
            Home ->
                pageConcept model

            Login ->
                pageLogin model

            Logout ->
                pageLogout model

            Register ->
                pageRegister model

            Profile ->
                pageProfile model

            Transactions ->
                pageTransaction model

            NotFound ->
                pageNotFound


pageLogout : Model -> List (Html Msg)
pageLogout model =
    [ text "Logged Out"
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
                        , apiActionResponse = { status = 0, resourceId = 0 }
                        , session =
                            case url.fragment of
                                Just "logout" ->
                                    { loginExpire = "", loginToken = "" }

                                _ ->
                                    model.session
                      }
                    , case url.fragment of
                        Just "logout" ->
                            Nav.pushUrl model.navKey "#"

                        _ ->
                            Nav.pushUrl model.navKey (Url.toString url)
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
                    ( { model | problems = [], loading = Loading.On }
                    , login validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedRegisterForm ->
            case registerValidate model.registerForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , register validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedProfileForm ->
            case profileValidate model.profileForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , profile model.session.loginToken validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedTransactionForm ->
            case transactionValidate model.transactionForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , transaction model validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
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

        EnteredRegisterConfirmPassword passwordConfirm ->
            registerUpdateForm (\form -> { form | password_confirm = passwordConfirm }) model

        EnteredUserFirstName firstName ->
            profileUpdateForm (\form -> { form | firstName = firstName }) model

        EnteredUserMidNames midNames ->
            profileUpdateForm (\form -> { form | midNames = midNames }) model

        EnteredUserLastName lastName ->
            profileUpdateForm (\form -> { form | lastName = lastName }) model

        EnteredUserLocation location ->
            profileUpdateForm (\form -> { form | location = location }) model

        EnteredUserMobile mobile ->
            profileUpdateForm (\form -> { form | mobile = mobile }) model

        EnteredUserEmail email ->
            profileUpdateForm (\form -> { form | email = email }) model

        EnteredTransactionEmail email ->
            transactionUpdateForm (\form -> { form | email = email }) model

        EnteredTransactionTGs tgs ->
            let
                newTime =
                    timeFromTgs tgs model.transactionForm.multiplier
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, time = newTime }) model

        EnteredTransactionTime time ->
            let
                tgs =
                    tgsFromTimeAndMultiplier time model.transactionForm.multiplier
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, time = time }) model

        EnteredTransactionMultiplier multiplier ->
            let
                tgs =
                    tgsFromTimeAndMultiplier model.transactionForm.time multiplier
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, multiplier = multiplier }) model

        TransactionState state ->
            ( { model | creatingTransaction = state }
            , Cmd.none
            )

        CompletedLogin (Err error) ->
            let
                serverErrors =
                    decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
            , Cmd.none
            )

        CompletedLogin (Ok res) ->
            ( { model | session = res, loading = Loading.Off }
            , loadUser res.loginToken 0
            )

        LoadedUser (Err error) ->
            ( { model | loading = Loading.Off }
            , Cmd.none
            )

        LoadedUser (Ok res) ->
            ( { model | loggedInUser = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedProfile (Err error) ->
            ( { model | loading = Loading.Off }
            , Cmd.none
            )

        LoadedProfile (Ok res) ->
            ( { model | profileForm = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedConcept (Err error) ->
            ( { model | loading = Loading.Off }
            , Cmd.none
            )

        LoadedConcept (Ok res) ->
            ( { model | concept = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedTransactions (Err error) ->
            ( { model | loading = Loading.Off }
            , Cmd.none
            )

        LoadedTransactions (Ok res) ->
            let
                tx =
                    List.filter (\t -> t.status > 2) res

                pendingTx =
                    List.filter (\t -> t.status == 1 || t.status == 2) res
            in
            ( { model | transactions = tx, pendingTransactions = pendingTx, loading = Loading.Off }
            , Cmd.none
            )

        LoadedTxUsers (Err error) ->
            ( { model | loading = Loading.Off }
            , Cmd.none
            )

        LoadedTxUsers (Ok res) ->
            let
                userDict =
                    Dict.fromList (List.map indexUser res)
            in
            ( { model | txUsers = userDict, loading = Loading.Off }
            , Cmd.none
            )

        GotRegisterJson result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }, Cmd.none )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }, Cmd.none )

        GotUpdateProfileJson result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }, Cmd.none )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }, Cmd.none )

        AddedTransaction result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }, loadTransactions model )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
                    , Cmd.none
                    )

        AcceptedTransaction result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }, loadTransactions model )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
                    , loadTransactions model
                    )

        RejectedTransaction result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }, loadTransactions model )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
                    , loadTransactions model
                    )

        AcceptTransaction txId ->
            ( { model | loading = Loading.On }
            , acceptTransaction model txId
            )

        RejectTransaction txId ->
            ( { model | loading = Loading.On }
            , rejectTransaction model txId
            )

        AdjustTimeZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        TimeTick posix ->
            ( { model | time = posix }, Cmd.none )


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

        BadStatus 401 ->
            [ "Invalid Username or Password" ]

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

        Just page ->
            ( { model | page = page }
            , if page == Profile then
                loadProfile model.session.loginToken

              else if page == Home then
                loadConcept "index"

              else if page == Transactions then
                Cmd.batch [ loadTransactions model, loadTxUsers model ]

              else
                Cmd.none
            )


decode : Url -> Maybe Page
decode url =
    { url | path = Maybe.withDefault "" url.fragment, fragment = Nothing }
        |> UrlParser.parse routeParser


routeParser : Parser (Page -> a) a
routeParser =
    UrlParser.oneOf
        [ UrlParser.map Home top
        , UrlParser.map Login (s "login")
        , UrlParser.map Logout (s "logout")
        , UrlParser.map Register (s "register")
        , UrlParser.map Transactions (s "transaction")
        , UrlParser.map Profile (s "profile")
        ]



-- HTTP


loadUser : String -> Int -> Cmd Msg
loadUser token userId =
    Http.request
        { method = "GET"
        , url = "/api/users/" ++ String.fromInt userId
        , expect = Http.expectJson LoadedUser userDecoder
        , headers = [ authHeader token ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


loadProfile : String -> Cmd Msg
loadProfile token =
    Http.request
        { method = "GET"
        , url = "/api/users/0"
        , expect = Http.expectJson LoadedProfile profileDecoder
        , headers = [ authHeader token ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


loadConcept : String -> Cmd Msg
loadConcept concept =
    Http.request
        { method = "GET"
        , url = "/api/concept/" ++ concept
        , expect = Http.expectJson LoadedConcept conceptDecoder
        , headers = []
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Navbar.subscriptions model.navState NavMsg
        , Time.every (30 * 1000) TimeTick
        ]
