module Main exposing (main)

import Bootstrap.Grid as Grid
import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Concept exposing (loadConceptTagsList, loadConcepts, pageConcept)
import ConceptsEdit exposing (concept, conceptDeleteSelectedTags, conceptTag, conceptTagUpdateForm, conceptTagValidate, conceptUpdateForm, conceptValidate, loadConceptById, loadConceptTagsById, pageConceptsEdit, tagIsNotIn)
import ConceptsList exposing (pageConceptsList)
import Dict
import Html exposing (..)
import Html.Attributes exposing (href)
import Http exposing (Error(..), emptyBody)
import Json.Decode as Decode exposing (Decoder, field)
import Loading
import Login exposing (loggedIn, login, loginUpdateForm, loginValidate, pageLogin, userIsEditor)
import Ports exposing (storeExpire, storeToken)
import Profile exposing (pageProfile, profile, profileUpdateForm, profileValidate)
import Register exposing (pageRegister, register, registerUpdateForm, registerValidate)
import Set
import Task
import Time
import Transaction exposing (acceptTransaction, loadTransactions, loadTxUsers, pageTransaction, rejectTransaction, transaction, transactionUpdateForm, transactionValidate)
import Types exposing (LoginForm, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionType(..), User, authHeader, conceptDecoder, displayableTagsListFrom, indexUser, isNot, profileDecoder, tgsFromTimeAndMultiplier, timeFromTgs, timeFromTime, txFeeFromTgsAndMultiplier, userDecoder)
import Url exposing (Url)
import Url.Parser as UrlParser exposing ((</>), Parser, s, string, top)



-- TYPES


type alias Flags =
    { token : Maybe String
    , expire : Maybe String
    }



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
                , problems = []
                , loginForm = { email = "", password = "" }
                , registerForm = { email = "", password = "", password_confirm = "" }
                , session = { loginExpire = Maybe.withDefault "" flags.expire, loginToken = Maybe.withDefault "" flags.token }
                , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
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
                    , description = ""
                    , txFee = "00:00:01"
                    }
                , conceptForm =
                    { name = ""
                    , tags = []
                    , tagsToDelete = Set.empty
                    , summary = ""
                    , full = ""
                    }
                , conceptTagForm = { tag = "" }
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
                , conceptsList = []
                , conceptTagsList = []
                , displayableTagsList = []
                , conceptShowTagModel = Modal.hidden
                }
    in
    ( model
    , Cmd.batch
        [ urlCmd
        , navCmd
        , case flags.token of
            Just token ->
                loadUser token 0

            Nothing ->
                Cmd.none
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
                Navbar.itemLink [ href "#transactions" ] [ text "Transactions" ]

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

            Concepts _ ->
                pageConcept model

            ConceptsList ->
                pageConceptsList model

            ConceptsEdit _ ->
                pageConceptsEdit model


pageLogout : Model -> List (Html Msg)
pageLogout model =
    [ text "Logged Out"
    ]


pageNotFound : List (Html Msg)
pageNotFound =
    [ h1 [] [ text "Not found" ]
    , text "Sorry couldn't find that page"
    ]



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
                        , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                        , session =
                            case url.fragment of
                                Just "logout" ->
                                    { loginExpire = "", loginToken = "" }

                                _ ->
                                    model.session
                      }
                    , case url.fragment of
                        Just "logout" ->
                            Cmd.batch
                                [ Nav.pushUrl model.navKey "#"
                                , storeToken Nothing
                                , storeExpire Nothing
                                ]

                        _ ->
                            Nav.pushUrl model.navKey (Url.toString url)
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        ChangedUrl url ->
            urlUpdate url model

        NavMsg state ->
            ( { model | navState = state }, Cmd.none )

        CloseConceptAddTagModal ->
            ( { model | conceptShowTagModel = Modal.hidden }, Cmd.none )

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

        SubmittedConceptForm ->
            case conceptValidate model.conceptForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , concept model validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedAddConceptTagForm ->
            case conceptTagValidate model.conceptTagForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , conceptTag model validForm
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

                txFee =
                    txFeeFromTgsAndMultiplier tgs model.transactionForm.multiplier
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, time = newTime, txFee = txFee }) model

        EnteredTransactionTime time ->
            let
                tgs =
                    tgsFromTimeAndMultiplier time model.transactionForm.multiplier

                newTime =
                    timeFromTime time

                txFee =
                    txFeeFromTgsAndMultiplier tgs model.transactionForm.multiplier
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, time = newTime, txFee = txFee }) model

        EnteredTransactionMultiplier multiplier ->
            let
                tgs =
                    tgsFromTimeAndMultiplier model.transactionForm.time multiplier

                txFee =
                    txFeeFromTgsAndMultiplier tgs multiplier
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, multiplier = multiplier, txFee = txFee }) model

        EnteredTransactionDescription description ->
            transactionUpdateForm (\form -> { form | description = description }) model

        EnteredConceptName name ->
            conceptUpdateForm (\form -> { form | name = name }) model

        EnteredConceptTagCheckToDelete tagId tagState ->
            let
                tags =
                    if tagState then
                        Set.insert tagId model.conceptForm.tagsToDelete

                    else
                        Set.filter (isNot tagId) model.conceptForm.tagsToDelete
            in
            conceptUpdateForm (\form -> { form | tagsToDelete = tags }) model

        EnteredConceptSummary summary ->
            conceptUpdateForm (\form -> { form | summary = summary }) model

        EnteredConceptFull full ->
            conceptUpdateForm (\form -> { form | full = full }) model

        EnteredAddConceptTag tag ->
            conceptTagUpdateForm (\form -> { form | tag = tag }) model

        ButtonConceptAddTag ->
            ( { model | conceptShowTagModel = Modal.shown }, Cmd.none )

        ButtonConceptDeleteSelectedTags ->
            ( { model | loading = Loading.On }, conceptDeleteSelectedTags model )

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
            , Cmd.batch
                [ storeToken Nothing
                , storeExpire Nothing
                ]
            )

        CompletedLogin (Ok res) ->
            ( { model | session = res, loading = Loading.Off }
            , Cmd.batch
                [ loadUser res.loginToken 0
                , storeToken (Just res.loginToken)
                , storeExpire (Just res.loginExpire)
                ]
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
            let
                concept =
                    { id = 0
                    , name = ""
                    , summary = ""
                    , full = ""
                    , tags = []
                    }

                conceptForm =
                    { name = ""
                    , tags = []
                    , tagsToDelete = Set.empty
                    , summary = ""
                    , full = ""
                    }
            in
            ( { model
                | concept =
                    concept
                , conceptForm =
                    conceptForm
                , loading = Loading.Off
              }
            , Cmd.none
            )

        LoadedConcept (Ok res) ->
            let
                conceptForm =
                    { name = res.name
                    , tags = model.conceptForm.tags
                    , tagsToDelete = Set.empty
                    , summary = res.summary
                    , full = res.full
                    }
            in
            ( { model | concept = res, conceptForm = conceptForm, loading = Loading.Off }
            , Cmd.none
            )

        LoadedConceptTags (Err error) ->
            let
                serverErrors =
                    decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
            , Cmd.none
            )

        LoadedConceptTags (Ok res) ->
            let
                conceptForm =
                    { name = model.conceptForm.name
                    , tags = res
                    , tagsToDelete = model.conceptForm.tagsToDelete
                    , summary = model.conceptForm.summary
                    , full = model.conceptForm.full
                    }
            in
            ( { model | conceptForm = conceptForm, problems = [], loading = Loading.Off }
            , Cmd.none
            )

        LoadedConcepts (Err error) ->
            ( { model | loading = Loading.Off }
            , Cmd.none
            )

        LoadedConcepts (Ok res) ->
            let
                dTags =
                    displayableTagsListFrom model.conceptTagsList res
            in
            ( { model | conceptsList = res, displayableTagsList = dTags, loading = Loading.Off }
            , Cmd.none
            )

        LoadedConceptTagsList (Err error) ->
            let
                serverErrors =
                    decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
            , Cmd.none
            )

        LoadedConceptTagsList (Ok res) ->
            let
                dTags =
                    displayableTagsListFrom res model.conceptsList
            in
            ( { model | conceptTagsList = res, displayableTagsList = dTags, loading = Loading.Off }
            , Cmd.none
            )

        ConceptTagDeleted (Err error) ->
            let
                serverErrors =
                    decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
            , Cmd.none
            )

        ConceptTagDeleted (Ok res) ->
            let
                conceptFormTags =
                    List.filter (tagIsNotIn (Set.fromList res.resourceIds)) model.conceptForm.tags

                conceptForm =
                    { name = model.conceptForm.name
                    , summary = model.conceptForm.summary
                    , full = model.conceptForm.full
                    , tagsToDelete = model.conceptForm.tagsToDelete
                    , tags = conceptFormTags
                    }
            in
            ( { model | conceptForm = conceptForm, loading = Loading.Off }
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

        AddedConcept result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }
                    , loadConceptById res.resourceId
                    )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
                    , Cmd.none
                    )

        AddedConceptTag conceptId tag result ->
            case result of
                Ok res ->
                    let
                        conceptTag =
                            { id = res.resourceId, tag = tag, conceptId = conceptId, order = 0 }

                        conceptFormTags =
                            model.conceptForm.tags ++ [ conceptTag ]

                        conceptForm =
                            { name = model.conceptForm.name
                            , summary = model.conceptForm.summary
                            , full = model.conceptForm.full
                            , tagsToDelete = model.conceptForm.tagsToDelete
                            , tags = conceptFormTags
                            }

                        tags =
                            model.concept.tags
                                ++ [ { id = res.resourceId
                                     , order = 0
                                     , tag = tag
                                     }
                                   ]

                        concept =
                            { id = model.concept.id
                            , name = model.concept.name
                            , summary = model.concept.summary
                            , full = model.concept.full
                            , tags = tags
                            }
                    in
                    ( { model | concept = concept, conceptForm = conceptForm, apiActionResponse = res, loading = Loading.Off }
                    , Cmd.none
                    )

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
            , case page of
                Profile ->
                    loadProfile model.session.loginToken

                Home ->
                    Cmd.batch [ loadConcept "index", loadConceptTagsList model, loadConcepts model ]

                Concepts tag ->
                    Cmd.batch [ loadConcept tag, loadConceptTagsList model, loadConcepts model ]

                ConceptsEdit id ->
                    let
                        conceptId =
                            Maybe.withDefault 0 (String.toInt id)
                    in
                    Cmd.batch [ loadConceptById conceptId, loadConceptTagsById conceptId ]

                ConceptsList ->
                    Cmd.batch [ loadConcepts model, loadConceptTagsList model ]

                Transactions ->
                    Cmd.batch [ loadTransactions model, loadTxUsers model ]

                _ ->
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
        , UrlParser.map Transactions (s "transactions")
        , UrlParser.map Profile (s "profile")
        , UrlParser.map Concepts (s "concepts" </> string)
        , UrlParser.map ConceptsEdit (s "concepts" </> string </> s "edit")
        , UrlParser.map ConceptsList (s "concepts")
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
