module Types exposing (ApiPostResponse, LoginForm, Model, Msg(..), Page(..), Problem(..), RegisterForm, Session, User, ValidatedField(..), userDecoder)

import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Http
import Json.Decode exposing (Decoder, at, int, map7, map8, string)
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
    , loggedInUser : User
    }


type Page
    = Home
    | Login
    | Logout
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


type alias User =
    { id : Int
    , firstName : String
    , midNames : String
    , lastName : String
    , location : String
    , email : String
    , mobile : String
    , permissions : Int
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
    | LoadedUser (Result Http.Error User)



-- DECODERS


userDecoder : Decoder User
userDecoder =
    map8 User
        (at [ "ID" ] int)
        (at [ "FirstName" ] string)
        (at [ "MidNames" ] string)
        (at [ "LastName" ] string)
        (at [ "Location" ] string)
        (at [ "Email" ] string)
        (at [ "Mobile" ] string)
        (at [ "Permissions" ] int)
