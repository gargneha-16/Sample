import { LightningElement } from 'lwc';

import dynamicExpressions from './dynamicExpressions';

import Dynamic_Parameter_Helper from '@salesforce/label/c.Dynamic_Parameter_Helper';
import Parameter_Context from '@salesforce/label/c.Parameter_Context';
import Parameter_Field from '@salesforce/label/c.Parameter_Field';
import Variable_Value from '@salesforce/label/c.VarVal';
import Dynamic_Variable_Helper_Helptext from '@salesforce/label/c.Dynamic_Variable_Helper_Helptext';
import COPY_TO_CLIPBOARD from '@salesforce/label/c.COPY_TO_CLIPBOARD';

export default class DynamicExpressionHelper extends LightningElement {
    label = {
        Variable_Value,
        Parameter_Field,
        Parameter_Context,
        COPY_TO_CLIPBOARD,
        Dynamic_Parameter_Helper,
        Dynamic_Variable_Helper_Helptext
    };

    selectedValues = [];

    value = 'inProgress';

    get context() {
        return dynamicExpressions;
    }

    get parameter1() {
        const selectedContext = this.getSelectedOption(this.context.options, this.selectedValues[0]);

        return selectedContext || {};
    }

    get parameter2() {
        const selectedContext = this.getSelectedOption(this.parameter1.options, this.selectedValues[1]);

        return selectedContext || {};
    }

    get parameter3() {
        const selectedContext = this.getSelectedOption(this.parameter2.options, this.selectedValues[2]);

        return selectedContext || {};
    }

    get parameter4() {
        const selectedContext = this.getSelectedOption(this.parameter3.options, this.selectedValues[3]);

        return selectedContext || {};
    }

    get hasParameterOptions1() {
        return (this.parameter1?.options?.length && !this.parameter1.isFieldSelector);
    }

    get hasParameterOption2() {
        return (this.parameter2?.options?.length && !this.parameter2.isFieldSelector);
    }

    get hasParameterOption3() {
        return (this.parameter3?.options?.length && !this.parameter3.isFieldSelector);
    }

    get hasParameterOption4() {
        return (this.parameter4?.options?.length && !this.parameter4.isFieldSelector);
    }

    get selectedExpression() {
        const values = this.selectedValues.filter(value => !!value);

        return (values.length ? `{$${values.join('.')}}` : '');
    }

    handleChange(event) {
        const index = Number(event.target.getAttribute('data-index'));
        this.selectedValues[index] = event.detail.value;

        this.selectedValues = this.selectedValues.map((value, currentIndex) => {
            return currentIndex <= index ? value : null;
        });
    }

    copyToClipboard() {
        const element = this.template.querySelector("textarea");
        element.select();
        document.execCommand("copy");
        const button = this.template.querySelector("lightning-button");
        button.label = "Copied!";
        button.iconName = "utility:check";

        setTimeout(() => {
            button.iconName = "utility:copy";
            button.label = COPY_TO_CLIPBOARD;
        }, 1500);
    }

    getSelectedOption(list, value) {
        return list?.filter(element => element.value === value)[0];
    }
}