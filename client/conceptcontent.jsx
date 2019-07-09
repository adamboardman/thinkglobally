import React from "react";
import PropTypes from 'prop-types';
import {Link} from "react-router-dom";
import ReactMarkdownConcepts from "react-markdown-concepts";

class ConceptContent extends React.Component {
    constructor(props) {
        super(props);

        this.state = {
            loadedId: 0,
            swapTried: false,
        };
    }

    render() {
        const {loginToken, concept} = this.props;
        const displayableTagsList = (this.props.displayableTagsList && concept) ? this.props.displayableTagsList.filter(function(value, index, arr){
            return value.id !== concept.ID;
        }) : [];
        return (
            <div className="container">
                <h5>{concept ? concept.Name : ''}</h5>
                <ReactMarkdownConcepts source={concept ? concept.Full : ''} concepts={displayableTagsList}/>
                {loginToken.length > 0 &&
                <p>

                    <Link
                        to={concept ? "/concepts/" + concept.ID + "/edit" : ''}
                        className="btn btn-primary">Edit</Link>
                </p>
                }
            </div>
        );
    }
}

ConceptContent.propTypes = {
    loginToken: PropTypes.string,
    concept: PropTypes.object,
    displayableTagsList: PropTypes.array,
};

export default ConceptContent;
