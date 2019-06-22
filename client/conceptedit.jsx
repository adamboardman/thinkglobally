import React from "react";
import {loadConcept, updateConcept} from "#app/actions";
import {Link, Redirect} from "react-router-dom";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import ConceptEditContent from "./concepteditcontent";
import {Spinner} from "#app/components/spinner";

class ConceptEdit extends React.Component {
    constructor(props) {
        super(props);
    }

    componentDidMount() {
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        const id = this.props.match.params.id;
        this.props.loadConcept(id, headers);
    }

    render() {
        if (this.props.loginToken.length === 0) {
            return (<Redirect to="/"/>);
        } else {
            return (
                <div className="container">
                    <div className="col-lg-12 jumbotron">
                        <h1>Edit Concept</h1>
                        {this.props.concept === undefined ? (
                            <Spinner/>
                        ) : (
                            <ConceptEditContent
                                concept={this.props.concept}
                                isFetching={this.props.isFetching}
                                loginToken={this.props.loginToken}/>
                        )}
                        <p>Or</p>
                        <Link to="/concepts" className="btn btn-primary">Back</Link>
                    </div>
                </div>
            );
        }
    }
}

ConceptEdit.propTypes = {
    match: PropTypes.object.isRequired,
    loadConcept: PropTypes.func.isRequired,
    updateConcept: PropTypes.func.isRequired,
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    lastUpdated: PropTypes.number,
    emailConfirmed: PropTypes.bool,
    concept: PropTypes.object,
};

const mapStateToProps = (state) => {
    return {
        isFetching: state.isFetching,
        loginToken: state.loginToken,
        lastUpdated: state.lastUpdated,
        emailConfirmed: state.emailConfirmed,
        concept: state.concept,
    };
};

const mapDispatchToProps = (dispatch) => {
    return {
        loadConcept: (conceptId, headers) => dispatch(loadConcept(conceptId, headers)),
        updateConcept: (conceptId, headers, conceptInfo) => dispatch(updateConcept(conceptId, headers, conceptInfo)),
    };
};

export default connect(mapStateToProps, mapDispatchToProps)(ConceptEdit);
