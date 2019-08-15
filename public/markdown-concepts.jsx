const React = require('react');
const ReactDOM = require('react-dom');
const MarkdownConcepts = require('react-markdown-concepts');

class ReactMarkdownConcepts extends HTMLElement {
    set source(value) {
        this._source = value;
        this.render();
    }

    set concepts(value) {
        this._concepts = value;
        this.render();
    }

    render() {
        if (this._source) {
            ReactDOM.render(
                React.createElement(MarkdownConcepts,
                    {
                        source: this._source,
                        concepts: this._concepts
                    },
                    []
                ),
                this
            );
        }
    }
}

customElements.define('react-markdown-concepts', ReactMarkdownConcepts);