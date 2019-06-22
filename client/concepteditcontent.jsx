import React from "react";
import {
    addConcept,
    loadConcept,
    updateConcept
} from "#app/actions";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';

class ConceptEditContent extends React.Component {
    constructor(props) {
        super(props);

        this.handleUpdateConcept = this.handleUpdateConcept.bind(this);

        this.state = {
            show: false,
            inputId: this.props.concept ? this.props.concept.ID : 0,
            inputName: this.props.concept ? this.props.concept.Name : '',
            inputSummary: this.props.concept ? this.props.concept.Summary : '',
            inputFull: this.props.concept ? this.props.concept.Full : '',
        };
    }

    updateInputValueName(event) {
        this.setState({
            inputName: event.target.value
        });
    }

    updateInputValueSummary(event) {
        this.setState({
            inputSummary: event.target.value
        });
    }

    updateInputValueFull(event) {
        this.setState({
            inputFull: event.target.value
        });
    }

    handleUpdateConcept(event) {
        event.preventDefault();
        if (!event.target.checkValidity()) {
            event.target.classList.add('was-validated');
            return;
        }
        const userData = {
            ID: this.state.inputId,
            Name: this.state.inputName,
            Summary: this.state.inputSummary,
            Full: this.state.inputFull,
        };
        const data = JSON.stringify(userData);

        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        if (this.props.concept) {
            this.props.updateConcept(this.props.concept.ID, headers, data);
        } else {
            this.props.addConcept(headers, data);
        }
    }

    render() {
        const concept = this.props.concept;
        const isFetching = this.props.isFetching;

        return (
            <div>
                <form onSubmit={this.handleUpdateConcept} noValidate>
                    <div className="form-group">
                        <label htmlFor="name">Concept Name</label>
                        <input
                            type="text" className="form-control" id="name" name="name"
                            defaultValue={concept ? concept.Name : ''}
                            onChange={evt => this.updateInputValueName(evt)}
                            placeholder="Enter name" required/>
                    </div>
                    <div className="form-group">
                        <label htmlFor="summary">Summary</label>
                        <textarea
                            className="form-control" rows="3" name="summary" id="summary"
                            onChange={evt => this.updateInputValueSummary(evt)}
                            defaultValue={concept ? concept.Summary : ''}/>
                    </div>
                    <div className="form-group">
                        <label htmlFor="full">Full</label>
                        <textarea
                            className="form-control" rows="3" name="full" id="full"
                            onChange={evt => this.updateInputValueFull(evt)}
                            defaultValue={concept ? concept.Full : ''}/>
                    </div>
                    <button className="btn btn-primary" disabled={isFetching}>
                        {
                            isFetching
                                ? "In progress"
                                : "Save Concept"
                        }
                    </button>
                </form>
            </div>
        );
    }
}

ConceptEditContent.propTypes = {
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    addConcept: PropTypes.func.isRequired,
    updateConcept: PropTypes.func.isRequired,
    concept: PropTypes.object,
};

const mapStateToContentProps = (state) => {
    return {
        isFetching: state.isFetching,
        loginToken: state.loginToken,
        lastUpdated: state.lastUpdated,
        emailConfirmed: state.emailConfirmed,
        concept: state.concept,
    };
};

const mapDispatchToContentProps = (dispatch) => {
    return {
        loadConcept: (conceptId, headers) => dispatch(loadConcept(conceptId, headers)),
        addConcept: (headers, conceptInfo) => dispatch(addConcept(headers, conceptInfo)),
        updateConcept: (conceptId, headers, conceptInfo) => dispatch(updateConcept(conceptId, headers, conceptInfo)),
    };
};

export default connect(mapStateToContentProps, mapDispatchToContentProps)(ConceptEditContent);
