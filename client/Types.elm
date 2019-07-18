module Types exposing (ApiPostResponse, LoginForm, Model, Msg(..), Page(..), Problem(..), ProfileForm, RegisterForm, Session, User, ValidatedField(..), authHeader, profileDecoder, userDecoder)

import Bootstrap.Modal as Modal
import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import Http
import Json.Decode exposing (Decoder, at, int, map6, map7, map8, string)
import Url exposing (Url)


type alias Model =
    { navKey : Nav.Key
    , page : Page
    , navState : Navbar.State
    , modalVisibility : Modal.Visibility
    , problems : List Problem
    , loginForm : LoginForm
    , registerForm : RegisterForm
    , profileForm : ProfileForm
    , session : Session
    , postResponse : ApiPostResponse
    , loggedInUser : User
    }


type Page
    = Home
    | Login
    | Logout
    | Register
    | Profile
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


type alias ProfileForm =
    { id : Int
    , firstName : String
    , midNames : String
    , lastName : String
    , location : String
    , email : String
    , mobile : String
    }


type ValidatedField
    = Email
    | Password
    | ConfirmPassword
    | FirstName
    | MidNames
    | LastName
    | Location
    | Mobile


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
    | SubmittedProfileForm
    | EnteredLoginEmail String
    | EnteredLoginPassword String
    | EnteredRegisterEmail String
    | EnteredRegisterPassword String
    | EnteredRegisterConfirmPassword String
    | EnteredUserFirstName String
    | EnteredUserMidNames String
    | EnteredUserLastName String
    | EnteredUserLocation String
    | EnteredUserMobile String
    | EnteredUserEmail String
    | CompletedLogin (Result Http.Error Session)
    | GotRegisterJson (Result Http.Error ApiPostResponse)
    | LoadedUser (Result Http.Error User)
    | LoadedProfile (Result Http.Error ProfileForm)
    | GotUpdateProfileJson (Result Http.Error ApiPostResponse)



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


profileDecoder : Decoder ProfileForm
profileDecoder =
    map7 ProfileForm
        (at [ "ID" ] int)
        (at [ "FirstName" ] string)
        (at [ "MidNames" ] string)
        (at [ "LastName" ] string)
        (at [ "Location" ] string)
        (at [ "Email" ] string)
        (at [ "Mobile" ] string)



-- AUTH HEADER


authHeader : String -> Http.Header
authHeader token =
    Http.header "authorization" ("Bearer " ++ token)
