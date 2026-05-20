module LivingWageLocationList exposing (..)

import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h4, text)
import Html.Attributes exposing (href)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Types exposing (..)


pageLivingWageLocationList : Model -> List (Html Msg)
pageLivingWageLocationList model =
    [ h4 [] [ text "Living Wage Location" ]
    , div [] (List.map livingWageLocationSummary model.livingWageLocationList)
    , div [] (List.map viewProblem model.problems)
    ]


livingWageLocationSummary : LivingWageLocation -> Html Msg
livingWageLocationSummary livingWageLocation =
    let
        locationDisplay =
            if String.length livingWageLocation.symbol > 0 then
                livingWageLocation.name ++ " (" ++ livingWageLocation.symbol ++ ")"

            else
                livingWageLocation.name
    in
    div []
        [ text locationDisplay
        , a [ href ("/living_wage_locations/" ++ String.fromInt livingWageLocation.id ++ "/edit") ]
            [ text "(edit)" ]
        ]



-- HTTP


loadLivingWageLocations : Model -> Cmd Msg
loadLivingWageLocations model =
    Http.request
        { method = "GET"
        , url = "/api/living_wage_locations"
        , expect = Http.expectJson LoadedLivingWageLocations livingWageLocationListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


loadLivingWageLocationById : Model -> Int -> Cmd Msg
loadLivingWageLocationById model livingWageLocationId =
    Http.request
        { method = "GET"
        , url = "/api/living_wage_locations/" ++ String.fromInt livingWageLocationId
        , expect = Http.expectJson LoadedLivingWageLocation livingWageLocationDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


livingWageLocationListDecoder : Decoder (List LivingWageLocation)
livingWageLocationListDecoder =
    list livingWageLocationDecoder
