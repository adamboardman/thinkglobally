import React from "react";
import {clearConcept} from "#app/actions";
import {Link} from "react-router-dom";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import ConceptEditContent from "./concepteditcontent";

class ConceptAdd extends React.Component {
    constructor(props) {
        super(props);

        this.props.clearConcept();
    }

    componentDidMount() {
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
    }

    render() {
        return (
            <div className="container">
                <div className="col-lg-12 jumbotron">
                    <p>Add a new concept</p>
                    <ConceptEditContent
                        concept={this.props.concept}
                        isFetching={this.props.isFetching}
                        loginToken={this.props.loginToken}/>
                    <p>Or</p>
                    <Link to="/concepts" className="btn btn-primary">Back</Link>
                </div>
            </div>
        );
    }
}

ConceptAdd.propTypes = {
    clearConcept: PropTypes.func.isRequired,
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
        clearConcept: () => dispatch(clearConcept())
    };
};

export default connect(mapStateToProps, mapDispatchToProps)(ConceptAdd);
