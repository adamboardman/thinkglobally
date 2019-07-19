module Concept exposing (pageConcept)

import Html exposing (Html, h4, text)
import Html.Attributes exposing (class)
import Markdown
import Types exposing (Model, Msg)


pageConcept : Model -> List (Html Msg)
pageConcept model =
    [ h4 [] [ text model.concept.name ]
    , Markdown.toHtml [ class "content" ] model.concept.full
    ]
