module Types exposing (ApiPostResponse, LoginForm, Model, Msg(..), Page(..), Problem(..), RegisterForm, Session, ValidatedField(..))

import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Http
import Url exposing (Url)


type alias Model =
    { navKey : Nav.Key
    , page : Page
    , navState : Navbar.State
    , modalVisibility : Modal.Visibility
    , problems : List Problem
    , loginForm : LoginForm
    , registerForm : RegisterForm
    , session : Session
    , postResponse : ApiPostResponse
    }


type Page
    = Home
    | Login
    | Register
    | NotFound


type alias Session =
    { loginExpire : String
    , loginToken : String
    }


type alias ApiPostResponse =
    { status : Int
    , resourceId : Int
    }


type alias LoginForm =
    { email : String
    , password : String
    }


type alias RegisterForm =
    { email : String
    , password : String
    , password_confirm : String
    }


type ValidatedField
    = Email
    | Password
    | ConfirmPassword


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type Msg
    = ChangedUrl Url
    | ClickedLink UrlRequest
    | NavMsg Navbar.State
    | CloseModal
    | ShowModal
    | SubmittedLoginForm
    | SubmittedRegisterForm
    | EnteredLoginEmail String
    | EnteredLoginPassword String
    | EnteredRegisterEmail String
    | EnteredRegisterPassword String
    | EnteredRegisterConfirmPassword String
    | CompletedLogin (Result Http.Error Session)
    | GotRegisterJson (Result Http.Error ApiPostResponse)
