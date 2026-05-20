module Concept exposing (pageConcept)

import FormValidation exposing (viewProblem)
import Html exposing (Html, div, h4, text)
import Markdown
import Types exposing (Concept, ConceptTag, Model, Msg(..))


pageConcept : Model -> List (Html Msg)
pageConcept model =
    [ h4 [] [ text model.concept.name ]
    , div [] <| Markdown.toHtml Nothing model.concept.full
    , div [] (List.map viewProblem model.problems)
    ]
