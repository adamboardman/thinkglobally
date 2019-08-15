module ReactMarkdownConcepts exposing (view)

import Html
import Html.Attributes
import Json.Decode


view :
    { source : Json.Decode.Value
    , concepts : Json.Decode.Value
    }
    -> Html.Html msg
view { source, concepts } =
    Html.node "react-markdown-concepts"
        [ Html.Attributes.property "source" source
        , Html.Attributes.property "concepts" concepts
        ]
        []
