module Concept exposing (conceptListDecoder, conceptTagsListDecoder, encodeDisplayableTag, encodeDisplayableTags, loadConceptTagsList, loadConcepts, pageConcept)

import FormValidation exposing (viewProblem)
import Html exposing (Html, div, h4, text)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Json.Encode
import Markdown
import ReactMarkdownConcepts
import Types exposing (Concept, ConceptTag, DisplayableTag, Model, Msg(..), authHeader, conceptDecoder, conceptTagDecoder)


encodeDisplayableTag : DisplayableTag -> Json.Encode.Value
encodeDisplayableTag tag =
    Json.Encode.object
        [ ( "id", Json.Encode.int tag.id )
        , ( "index", Json.Encode.string tag.index )
        , ( "summary", Json.Encode.string tag.summary )
        , ( "tags", Json.Encode.list Json.Encode.string tag.tags )
        ]


encodeDisplayableTags : List DisplayableTag -> Json.Encode.Value
encodeDisplayableTags tags =
    Json.Encode.list encodeDisplayableTag tags


pageConcept : Model -> List (Html Msg)
pageConcept model =
    [ h4 [] [ text model.concept.name ]
    , div [] <| Markdown.toHtml Nothing model.concept.full
    , div [] (List.map viewProblem model.problems)
    ]



-- HTTP


loadConcepts : Model -> Cmd Msg
loadConcepts model =
    Http.request
        { method = "GET"
        , url = "/api/concepts"
        , expect = Http.expectJson LoadedConcepts conceptListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


conceptListDecoder : Decoder (List Concept)
conceptListDecoder =
    list conceptDecoder


loadConceptTagsList : Model -> Cmd Msg
loadConceptTagsList model =
    Http.request
        { method = "GET"
        , url = "/api/concept_tags"
        , expect = Http.expectJson LoadedConceptTagsList conceptTagsListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


conceptTagsListDecoder : Decoder (List ConceptTag)
conceptTagsListDecoder =
    list conceptTagDecoder
