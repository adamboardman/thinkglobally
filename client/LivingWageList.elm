module LivingWageList exposing (..)

import FormValidation exposing (viewProblem)
import FormatNumber exposing (format)
import Html exposing (Html, a, div, h4, text)
import Html.Attributes exposing (href)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Types exposing (..)


pageLivingWageList : Model -> List (Html Msg)
pageLivingWageList model =
    [ h4 [] [ text "Living Wage" ]
    , div [] (List.map (livingWageSummary model) model.livingWageList)
    , div [] (List.map viewProblem model.problems)
    ]


livingWageSummary : Model -> LivingWage -> Html Msg
livingWageSummary model livingWage =
    let
        location =
            Maybe.withDefault emptyLivingWageLocation (List.head (List.filter (\lwl -> lwl.id == livingWage.locationId) model.livingWageLocationList))
    in
    div []
        [ text " Start Date: "
        , text (formatDate model livingWage.startDate)
        , text ", Stop Date: "
        , text (formatDate model livingWage.stopDate)
        , text ", Location: "
        , text location.name
        , text ", Wage: "
        , text location.symbol
        , text (format nationalLocale livingWage.wage)
        , text " "
        , a [ href ("/living_wages/" ++ String.fromInt livingWage.id ++ "/edit") ] [ text "(edit)" ]
        ]



-- HTTP


loadLivingWages : Model -> Cmd Msg
loadLivingWages model =
    Http.request
        { method = "GET"
        , url = "/api/living_wages"
        , expect = Http.expectJson LoadedLivingWages livingWageListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


loadLivingWageById : Model -> Int -> Cmd Msg
loadLivingWageById model livingWageId =
    Http.request
        { method = "GET"
        , url = "/api/living_wages/" ++ String.fromInt livingWageId
        , expect = Http.expectJson LoadedLivingWage livingWageDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


livingWageListDecoder : Decoder (List LivingWage)
livingWageListDecoder =
    list livingWageDecoder
