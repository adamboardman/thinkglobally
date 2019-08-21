module ConceptsList exposing (conceptSummary, pageConceptsList)

import Dict
import Dict.Extra exposing (fromListBy)
import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h4, text)
import Html.Attributes exposing (href)
import Types exposing (Concept, Model, Msg, idFromDisplayable)


pageConceptsList : Model -> List (Html Msg)
pageConceptsList model =
    [ h4 [] [ text "Concepts" ]
    , div [] (List.map (conceptSummary model) model.conceptsList)
    , div [] (List.map viewProblem model.problems)
    ]


conceptSummary : Model -> Concept -> Html Msg
conceptSummary model concept =
    div []
        [ text concept.name
        , a [ href ("#concepts/" ++ String.fromInt concept.id ++ "/edit") ]
            [ text "(edit)" ]
        , a [ href ("#concepts/" ++ findConceptIndex model concept.id) ]
            [ text "(view)" ]
        ]


findConceptIndex : Model -> Int -> String
findConceptIndex model conceptId =
    let
        groupedDisplayables =
            fromListBy idFromDisplayable model.displayableTagsList
    in
    case Dict.get conceptId groupedDisplayables of
        Just dTag ->
            dTag.index

        Nothing ->
            ""
