import React from "react";
import PropTypes from 'prop-types';
import {Link} from "react-router-dom";

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

        return (
            <div className="container">
                <h5>{concept ? concept.Name : ''}</h5>
                <p>{concept ? concept.Summary : ''}</p>
                <p>{concept ? concept.Full : ''}</p>
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
};

export default ConceptContent;
