module Main exposing (main)

import Bootstrap.Grid as Grid
import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Concept exposing (pageConcept)
import ConceptsEdit exposing (conceptAdd, conceptDeleteSelectedTags, conceptTag, conceptTagUpdateForm, conceptTagValidate, conceptUpdate, conceptUpdateForm, conceptValidate, loadConceptById, loadConceptTagsById, pageAddConcept, pageConceptsEdit, tagIsNotIn)
import ConceptsList exposing (loadConceptTagsList, loadConcepts, pageConceptsList)
import Date
import Dict
import Html exposing (Html, div, h1, text)
import Html.Attributes exposing (href)
import Http exposing (Error(..), emptyBody)
import Iso8601
import LivingWageEdit exposing (livingWageAdd, livingWageUpdate, livingWageUpdateForm, livingWageValidate, pageAddLivingWage, pageLivingWageEdit)
import LivingWageList exposing (loadLivingWageById, loadLivingWages, pageLivingWageList)
import LivingWageLocationEdit exposing (livingWageLocationAdd, livingWageLocationUpdate, livingWageLocationUpdateForm, livingWageLocationValidate, pageAddLivingWageLocation, pageLivingWageLocationEdit)
import LivingWageLocationList exposing (loadLivingWageLocationById, loadLivingWageLocations, pageLivingWageLocationList)
import Loading
import Login exposing (loggedIn, login, loginUpdateForm, loginValidate, pageLogin, userIsEditor)
import Ports exposing (storeExpire, storeToken)
import Profile exposing (pageProfile, profile, profileUpdateForm, profileValidate)
import Register exposing (pageRegister, register, registerUpdateForm, registerValidate)
import Set
import Task
import Time exposing (utc)
import Transaction exposing (loadTransactions, loadTxUsers, pageTransactionList)
import TransactionCreate exposing (pageTransactionCreate, transaction, transactionCheckBalance, transactionUpdateForm, transactionValidate)
import TransactionPending exposing (acceptTransaction, pageTransactionPending, rejectTransaction)
import Types exposing (LoginForm, Model, Msg(..), Page(..), Problem(..), Session, Transaction, TransactionFromType(..), TransactionType(..), User, authHeader, conceptDecoder, displayableTagsListFrom, emptyConcept, emptyConceptForm, emptyLivingWage, emptyLivingWageForm, emptyLivingWageLocation, emptyLivingWageLocationForm, emptyProfileForm, emptySession, emptyTransactionForm, emptyUser, indexUser, intHoursFromTgs, intMinutesFromTgs, intSecondsFromTgs, isNot, padAndCapTimePart, profileDecoder, tgsFromTimeHMSAndMultiplier, txFeeFromTgs, userDecoder)
import Url exposing (Url)
import Url.Parser as UrlParser exposing ((</>), (<?>), Parser, s, string, top)
import Url.Parser.Query as Query



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
                { navKey = Just key
                , navState = Just navState
                , page = Home
                , loading = Loading.Off
                , problems = []
                , loginForm = { email = "", password = "" }
                , registerForm = { email = "", password = "", password_confirm = "", verification = "" }
                , session = { loginExpire = Maybe.withDefault "" flags.expire, loginToken = Maybe.withDefault "" flags.token }
                , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                , loggedInUser = emptyUser
                , profileForm = emptyProfileForm
                , transactionForm = emptyTransactionForm
                , conceptForm = emptyConceptForm
                , conceptTagForm = { tag = "" }
                , concept = emptyConcept
                , creatingTransaction = TxNone
                , creatingTransactionFrom = TxFromTGs
                , transactions = []
                , pendingTransactions = []
                , txUsers = Dict.empty
                , creatingTransactionWithUser = emptyUser
                , timeZone = Time.utc
                , time = Time.millisToPosix 0
                , date = Time.millisToPosix 0
                , conceptsList = []
                , conceptTagsList = []
                , displayableTagsList = []
                , conceptShowTagModel = Modal.hidden
                , selectedTxId = 0
                , livingWage = emptyLivingWage
                , livingWageForm = emptyLivingWageForm
                , livingWageList = []
                , livingWageLocation = emptyLivingWageLocation
                , livingWageLocationForm = emptyLivingWageLocationForm
                , livingWageLocationList = []
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
    case model.navState of
        Just navState ->
            Navbar.config NavMsg
                |> Navbar.withAnimation
                |> Navbar.container
                |> Navbar.brand [ href (urlForPage Home) ] [ text "ThinkGlobally" ]
                |> Navbar.items
                    [ if userIsEditor model then
                        Navbar.dropdown
                            { id = "concepts_dropdown"
                            , toggle = Navbar.dropdownToggle [ href (urlForPage model.page) ] [ text "Concepts" ]
                            , items =
                                [ Navbar.dropdownItem
                                    [ href (urlForPage ConceptsList) ]
                                    [ text "Concepts" ]
                                , Navbar.dropdownItem
                                    [ href (urlForPage AddConcept) ]
                                    [ text "Add Concept" ]
                                ]
                            }

                      else
                        Navbar.itemLink [ href "" ] [ text "" ]
                    , if userIsEditor model then
                        Navbar.dropdown
                            { id = "living_wages_dropdown"
                            , toggle = Navbar.dropdownToggle [ href (urlForPage model.page) ] [ text "Living Wages" ]
                            , items =
                                [ Navbar.dropdownItem
                                    [ href (urlForPage LivingWageList) ]
                                    [ text "Living Wages" ]
                                , Navbar.dropdownItem
                                    [ href (urlForPage AddLivingWage) ]
                                    [ text "Add Living Wage" ]
                                , Navbar.dropdownItem
                                    [ href (urlForPage LivingWageLocationList) ]
                                    [ text "Living Wage Locations" ]
                                , Navbar.dropdownItem
                                    [ href (urlForPage AddLivingWageLocation) ]
                                    [ text "Add Living Wage Location" ]
                                ]
                            }

                      else
                        Navbar.itemLink [ href "" ] [ text "" ]
                    , if loggedIn model then
                        Navbar.itemLink [ href (urlForPage Profile) ] [ text "Profile" ]

                      else
                        Navbar.itemLink [ href "" ] [ text "" ]
                    , if loggedIn model then
                        Navbar.dropdown
                            { id = "transactions_dropdown"
                            , toggle = Navbar.dropdownToggle [ href (urlForPage model.page) ] [ text "Transactions" ]
                            , items =
                                [ Navbar.dropdownItem
                                    [ href (urlForPage Transactions) ]
                                    [ text "Pending Transactions" ]
                                , Navbar.dropdownItem
                                    [ href (urlForPage TransactionsList) ]
                                    [ text "Past Transactions" ]
                                , Navbar.dropdownItem
                                    [ href (urlForPage AddTransaction) ]
                                    [ text "Create Transaction" ]
                                ]
                            }

                      else
                        Navbar.itemLink [ href "" ] [ text "" ]
                    , if loggedIn model then
                        Navbar.itemLink [ href (urlForPage Logout) ] [ text "Logout" ]

                      else
                        Navbar.itemLink [ href (urlForPage Login) ] [ text "Login" ]
                    ]
                |> Navbar.view navState

        Nothing ->
            div [] []


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

            Register email _ ->
                pageRegister model email

            Profile ->
                pageProfile model

            Transactions ->
                pageTransactionPending model

            TransactionsList ->
                pageTransactionList model

            AddTransaction ->
                pageTransactionCreate model

            Concepts _ ->
                pageConcept model

            ConceptsList ->
                pageConceptsList model

            ConceptsEdit _ ->
                pageConceptsEdit model

            AddConcept ->
                pageAddConcept model

            LivingWageLocationList ->
                pageLivingWageLocationList model

            AddLivingWage ->
                pageAddLivingWage model

            AddLivingWageLocation ->
                pageAddLivingWageLocation model

            LivingWageList ->
                pageLivingWageList model

            LivingWageLocationEdit _ ->
                pageLivingWageLocationEdit model

            LivingWageEdit _ ->
                pageLivingWageEdit model

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
                        , registerForm = { email = "", password = "", password_confirm = "", verification = "" }
                        , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                        , session =
                            case url.path of
                                "/logout" ->
                                    emptySession

                                _ ->
                                    model.session
                      }
                    , case model.navKey of
                        Just navKey ->
                            case url.path of
                                "/logout" ->
                                    Cmd.batch
                                        [ Nav.pushUrl navKey (urlForPage Home)
                                        , storeToken Nothing
                                        , storeExpire Nothing
                                        ]

                                _ ->
                                    Nav.pushUrl navKey (Url.toString url)

                        Nothing ->
                            Cmd.none
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        ChangedUrl url ->
            urlUpdate url model

        NavMsg state ->
            ( { model | navState = Just state }, Cmd.none )

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
                    , if model.concept.id > 0 then
                        conceptUpdate model validForm

                      else
                        conceptAdd model validForm
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
            ( { model | creatingTransactionWithUser = emptyUser, transactionForm = (\form -> { form | email = email }) model.transactionForm }, Cmd.none )

        EnteredTransactionTGs tgs ->
            let
                newTimeH =
                    intHoursFromTgs tgs model.transactionForm.multiplier

                newTimeM =
                    intMinutesFromTgs tgs model.transactionForm.multiplier

                newTimeS =
                    intSecondsFromTgs tgs model.transactionForm.multiplier

                txFee =
                    txFeeFromTgs tgs

                locationId =
                    model.transactionForm.locationId

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                national =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat tgs) * livingWage.wage)
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, timeH = newTimeH, timeM = newTimeM, timeS = newTimeS, txFee = txFee, national = national }) model

        EnteredTransactionTimeH hours ->
            let
                tgs =
                    tgsFromTimeHMSAndMultiplier hours model.transactionForm.timeM model.transactionForm.timeS model.transactionForm.multiplier

                txFee =
                    txFeeFromTgs tgs

                locationId =
                    model.transactionForm.locationId

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                national =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat tgs) * livingWage.wage)
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, timeH = hours, txFee = txFee, national = national }) model

        EnteredTransactionTimeM minutes ->
            let
                newMinutes =
                    padAndCapTimePart minutes

                tgs =
                    tgsFromTimeHMSAndMultiplier model.transactionForm.timeH newMinutes model.transactionForm.timeS model.transactionForm.multiplier

                txFee =
                    txFeeFromTgs tgs

                locationId =
                    model.transactionForm.locationId

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                national =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat tgs) * livingWage.wage)
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, timeM = newMinutes, txFee = txFee, national = national }) model

        EnteredTransactionTimeS seconds ->
            let
                newSeconds =
                    padAndCapTimePart seconds

                tgs =
                    tgsFromTimeHMSAndMultiplier model.transactionForm.timeH model.transactionForm.timeM newSeconds model.transactionForm.multiplier

                txFee =
                    txFeeFromTgs tgs

                locationId =
                    model.transactionForm.locationId

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                national =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat tgs) * livingWage.wage)
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, timeS = newSeconds, txFee = txFee, national = national }) model

        EnteredTransactionMultiplier multiplier ->
            let
                tgs =
                    tgsFromTimeHMSAndMultiplier model.transactionForm.timeH model.transactionForm.timeM model.transactionForm.timeS multiplier

                txFee =
                    txFeeFromTgs tgs

                locationId =
                    model.transactionForm.locationId

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                national =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat tgs) * livingWage.wage)
            in
            transactionUpdateForm (\form -> { form | tgs = tgs, multiplier = multiplier, txFee = txFee, national = national }) model

        EnteredNational national ->
            let
                locationId =
                    model.transactionForm.locationId

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                tgs =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat national) / livingWage.wage)

                newTimeH =
                    intHoursFromTgs tgs model.transactionForm.multiplier

                newTimeM =
                    intMinutesFromTgs tgs model.transactionForm.multiplier

                newTimeS =
                    intSecondsFromTgs tgs model.transactionForm.multiplier

                txFee =
                    txFeeFromTgs tgs
            in
            transactionUpdateForm (\form -> { form | national = national, tgs = tgs, timeH = newTimeH, timeM = newTimeM, timeS = newTimeS, txFee = txFee }) model

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

        TransactionFromState state ->
            ( { model | creatingTransactionFrom = state }
            , Cmd.none
            )

        ButtonTransactionCheckBalance ->
            ( { model | loading = Loading.On }
            , transactionCheckBalance model
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
                , case model.navKey of
                    Just navKey ->
                        Nav.pushUrl navKey (urlForPage Home)

                    Nothing ->
                        Cmd.none
                ]
            )

        LoadedUser (Err error) ->
            ( { model | loggedInUser = emptyUser, loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedUser (Ok res) ->
            ( { model | loggedInUser = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedTransactionUserWithBalance (Err error) ->
            ( { model | creatingTransactionWithUser = emptyUser, loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedTransactionUserWithBalance (Ok res) ->
            ( { model | creatingTransactionWithUser = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedProfile (Err error) ->
            ( { model | profileForm = emptyProfileForm, loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedProfile (Ok res) ->
            let
                profileForm =
                    { id = res.id
                    , firstName = res.firstName
                    , midNames = res.midNames
                    , lastName = res.lastName
                    , location = res.location
                    , locationId = res.locationId
                    , email = res.email
                    , mobile = res.mobile
                    }
            in
            ( { model | profileForm = profileForm, loading = Loading.Off }
            , Cmd.none
            )

        LoadedConcept (Err error) ->
            ( { model
                | concept = emptyConcept
                , conceptForm = emptyConceptForm
                , loading = Loading.Off
                , session = sessionGivenAuthError error model
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
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
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
            ( { model | loading = Loading.Off, session = sessionGivenAuthError error model }
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
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
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
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
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
            ( { model | loading = Loading.Off, session = sessionGivenAuthError error model }
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
            ( { model | loading = Loading.Off, session = sessionGivenAuthError error model }
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
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
                    , Cmd.none
                    )

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
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
                    , Cmd.none
                    )

        AddedTransaction result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off, transactionForm = emptyTransactionForm, creatingTransaction = TxNone }, loadTransactions model )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
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

                        newSession =
                            sessionGivenAuthError error model
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = newSession }
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

                        newSession =
                            sessionGivenAuthError error model
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = newSession }
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

                        newSession =
                            sessionGivenAuthError error model
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = newSession }
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

                        newSession =
                            sessionGivenAuthError error model
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = newSession }
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

        ViewTransaction txId ->
            ( { model | selectedTxId = txId }, Cmd.none )

        AdjustTimeZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        TimeTick posix ->
            let
                dateIso =
                    String.fromInt (Date.year (Date.fromPosix utc posix))

                zeroDateTime =
                    Iso8601.fromTime (Time.millisToPosix 0)

                zeroTime =
                    String.slice (String.length dateIso) (String.length zeroDateTime) zeroDateTime

                dateZeroTime =
                    dateIso ++ zeroTime

                dateResult =
                    Iso8601.toTime dateZeroTime

                dateTime =
                    case dateResult of
                        Ok time ->
                            time

                        _ ->
                            model.time
            in
            ( { model | time = posix, date = dateTime }, Cmd.none )

        LoadedLivingWages (Err error) ->
            ( { model | loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedLivingWages (Ok res) ->
            ( { model | livingWageList = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedLivingWageLocations (Err error) ->
            ( { model | loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedLivingWageLocations (Ok res) ->
            ( { model | livingWageLocationList = res, loading = Loading.Off }
            , Cmd.none
            )

        EnteredLivingWageLocationName name ->
            livingWageLocationUpdateForm (\form -> { form | name = name }) model

        EnteredLivingWageLocationSymbol symbol ->
            livingWageLocationUpdateForm (\form -> { form | symbol = symbol }) model

        EnteredLivingWageWage wage ->
            livingWageUpdateForm (\form -> { form | wage = wage }) model

        SelectedLocationId location ->
            livingWageUpdateForm (\form -> { form | locationId = Maybe.withDefault 0 (String.toInt location) }) model

        SelectedProfileLocationId location ->
            profileUpdateForm (\form -> { form | locationId = Maybe.withDefault 0 (String.toInt location) }) model

        SelectedTransactionLocationId location ->
            let
                locationId =
                    Maybe.withDefault 0 (String.toInt location)

                livingWage =
                    TransactionCreate.findLivingWageForLocationIdAndDate model locationId model.transactionForm.date

                national =
                    String.fromFloat (Maybe.withDefault 0 (String.toFloat model.transactionForm.tgs) * livingWage.wage)
            in
            transactionUpdateForm (\form -> { form | locationId = locationId, national = national }) model

        SubmittedLivingWageForm ->
            case livingWageValidate model.livingWageForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , if model.livingWage.id > 0 then
                        livingWageUpdate model validForm

                      else
                        livingWageAdd model validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedLivingWageLocationForm ->
            case livingWageLocationValidate model.livingWageLocationForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , if model.livingWageLocation.id > 0 then
                        livingWageLocationUpdate model validForm

                      else
                        livingWageLocationAdd model validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        AddedLivingWage result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }
                    , loadLivingWageById model res.resourceId
                    )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError

                        newSession =
                            sessionGivenAuthError error model
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = newSession }
                    , Cmd.none
                    )

        AddedLivingWageLocation result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }
                    , loadLivingWageLocationById model res.resourceId
                    )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError

                        newSession =
                            sessionGivenAuthError error model
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = newSession }
                    , Cmd.none
                    )

        LoadedLivingWage (Err error) ->
            ( { model
                | livingWage = emptyLivingWage
                , livingWageForm = emptyLivingWageForm
                , loading = Loading.Off
                , session = sessionGivenAuthError error model
              }
            , Cmd.none
            )

        LoadedLivingWage (Ok res) ->
            let
                livingWageForm =
                    { startDate = Iso8601.fromTime res.startDate
                    , stopDate = Iso8601.fromTime res.stopDate
                    , locationId = res.locationId
                    , wage = String.fromFloat res.wage
                    }
            in
            ( { model | livingWage = res, livingWageForm = livingWageForm, loading = Loading.Off }
            , Cmd.none
            )

        EnteredStartDate startDate ->
            livingWageUpdateForm (\form -> { form | startDate = startDate }) model

        EnteredStopDate stopDate ->
            livingWageUpdateForm (\form -> { form | stopDate = stopDate }) model

        LoadedLivingWageLocation (Err error) ->
            ( { model
                | livingWageLocation = emptyLivingWageLocation
                , livingWageLocationForm = emptyLivingWageLocationForm
                , loading = Loading.Off
                , session = sessionGivenAuthError error model
              }
            , Cmd.none
            )

        LoadedLivingWageLocation (Ok res) ->
            let
                livingWageLocationForm =
                    { name = res.name
                    , symbol = res.symbol
                    }
            in
            ( { model | livingWageLocation = res, livingWageLocationForm = livingWageLocationForm, loading = Loading.Off }
            , Cmd.none
            )


sessionGivenAuthError : Http.Error -> Model -> Session
sessionGivenAuthError error model =
    if error == BadStatus 401 then
        emptySession

    else
        model.session


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


fromPair : ( String, List String ) -> List String
fromPair ( field, errors ) =
    List.map (\error -> field ++ " " ++ error) errors


urlForPage : Page -> String
urlForPage page =
    case page of
        Profile ->
            "/profile"

        Home ->
            "/"

        Login ->
            "/login"

        Logout ->
            "/logout"

        Register _ _ ->
            "/register"

        Transactions ->
            "/transactions/pending"

        TransactionsList ->
            "/transactions"

        AddTransaction ->
            "/add_transaction"

        Concepts string ->
            "/concepts/" ++ string

        ConceptsEdit string ->
            "/concepts/" ++ string ++ "/edit"

        ConceptsList ->
            "/concepts"

        NotFound ->
            ""

        AddConcept ->
            "/add_concept"

        LivingWageLocationList ->
            "/living_wage_locations"

        AddLivingWageLocation ->
            "/add_living_wage_location"

        LivingWageLocationEdit string ->
            "/living_wage_locations/" ++ string ++ "/edit"

        LivingWageList ->
            "/living_wages"

        AddLivingWage ->
            "/add_living_wage"

        LivingWageEdit string ->
            "/living_wages/" ++ string ++ "/edit"


urlUpdate : Url -> Model -> ( Model, Cmd Msg )
urlUpdate url model =
    case UrlParser.parse routeParser url of
        Nothing ->
            ( { model | page = NotFound }, Cmd.none )

        Just page ->
            ( case page of
                AddConcept ->
                    { model
                        | page = page
                        , concept = emptyConcept
                        , conceptForm = emptyConceptForm
                        , conceptTagForm = { tag = "" }
                    }

                AddLivingWageLocation ->
                    { model
                        | page = page
                        , livingWageLocation = emptyLivingWageLocation
                        , livingWageLocationForm = emptyLivingWageLocationForm
                    }

                AddLivingWage ->
                    { model
                        | page = page
                        , livingWage = emptyLivingWage
                        , livingWageForm =
                            { startDate = Iso8601.fromTime model.date
                            , stopDate = Iso8601.fromTime model.date
                            , locationId = 0
                            , wage = ""
                            }
                    }

                Register email verification ->
                    { model
                        | page = page
                        , registerForm =
                            { email = Maybe.withDefault "" email
                            , password = ""
                            , password_confirm = ""
                            , verification = Maybe.withDefault "" verification
                            }
                    }

                _ ->
                    { model | page = page }
            , case page of
                Profile ->
                    Cmd.batch [ loadProfile model.session.loginToken, loadLivingWageLocations model ]

                Home ->
                    Cmd.batch [ loadConcept "index" ]

                Concepts tag ->
                    Cmd.batch [ loadConcept tag ]

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

                TransactionsList ->
                    Cmd.batch [ loadTransactions model, loadTxUsers model ]

                AddTransaction ->
                    Cmd.batch [ loadTxUsers model, loadLivingWages model, loadLivingWageLocations model ]

                Login ->
                    Cmd.none

                Logout ->
                    Cmd.none

                Register _ _ ->
                    Cmd.none

                AddConcept ->
                    Cmd.none

                LivingWageList ->
                    Cmd.batch [ loadLivingWages model, loadLivingWageLocations model ]

                LivingWageLocationList ->
                    Cmd.batch [ loadLivingWageLocations model ]

                AddLivingWageLocation ->
                    Cmd.none

                AddLivingWage ->
                    Cmd.batch [ loadLivingWageLocations model ]

                LivingWageLocationEdit id ->
                    let
                        livingWageLocationId =
                            Maybe.withDefault 0 (String.toInt id)
                    in
                    Cmd.batch [ loadLivingWageLocationById model livingWageLocationId ]

                LivingWageEdit id ->
                    let
                        livingWageId =
                            Maybe.withDefault 0 (String.toInt id)
                    in
                    Cmd.batch [ loadLivingWageById model livingWageId, loadLivingWageLocations model ]

                NotFound ->
                    Cmd.none
            )


routeParser : Parser (Page -> a) a
routeParser =
    UrlParser.oneOf
        [ UrlParser.map Home top
        , UrlParser.map Login (s "login")
        , UrlParser.map Logout (s "logout")
        , UrlParser.map Register (s "register" <?> Query.string "email" <?> Query.string "verification")
        , UrlParser.map Transactions (s "transactions" </> s "pending")
        , UrlParser.map TransactionsList (s "transactions")
        , UrlParser.map AddTransaction (s "add_transaction")
        , UrlParser.map Profile (s "profile")
        , UrlParser.map Concepts (s "concepts" </> string)
        , UrlParser.map ConceptsEdit (s "concepts" </> string </> s "edit")
        , UrlParser.map ConceptsList (s "concepts")
        , UrlParser.map AddConcept (s "add_concept")
        , UrlParser.map LivingWageLocationList (s "living_wage_locations")
        , UrlParser.map AddLivingWageLocation (s "add_living_wage_location")
        , UrlParser.map LivingWageLocationEdit (s "living_wage_locations" </> string </> s "edit")
        , UrlParser.map LivingWageList (s "living_wages")
        , UrlParser.map AddLivingWage (s "add_living_wage")
        , UrlParser.map LivingWageEdit (s "living_wages" </> string </> s "edit")
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
        [ case model.navState of
            Just navState ->
                Navbar.subscriptions navState NavMsg

            Nothing ->
                Sub.none
        , Time.every (60 * 1000) TimeTick
        ]
