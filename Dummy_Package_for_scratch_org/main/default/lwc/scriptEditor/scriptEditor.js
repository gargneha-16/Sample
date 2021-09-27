import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';

import CODE_MIRROR from '@salesforce/resourceUrl/CodeMirror';

import SCRIPT from '@salesforce/schema/Function__c.Script__c';

import EDIT from '@salesforce/label/c.EDIT';
import CANCEL from '@salesforce/label/c.Cancel';
import SAVE from '@salesforce/label/c.Save';
import ERROR from '@salesforce/label/c.ERROR';
import SUCCESS from '@salesforce/label/c.SUCCESS';
import SCRIPT_UPDATED from '@salesforce/label/c.Script_Updated';
import ERROR_INITIALIZING_SCRIPT_EDITOR from '@salesforce/label/c.Error_Initializing_Script_Editor';

const FIELDS = [SCRIPT];

export default class ScriptEditor extends LightningElement {
    label = {
        EDIT,
        CANCEL,
        SAVE
    };

    @api recordId;

    loading = true;
    readOnly;
    editMode = false;
    function;
    editor;

    _script;

    @wire(getObjectInfo, { objectApiName: SCRIPT.objectApiName })
    wiredInfo({ error, data }) {
        if (error) {
            this.showToast(ERROR, error.body.message);
        } else if (data) {
            const field = data.fields[SCRIPT.fieldApiName];
            this.readOnly = !field.updateable;
            this.label.SCRIPT_LABEL = data.fields[SCRIPT.fieldApiName].label;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (error) {
            this.showToast(ERROR, error.body.message);
        } else if (data) {
            this.function = data;
            this.script = this.function.fields[SCRIPT.fieldApiName].value;
        }
    }

    async connectedCallback() {
        try {
            await this.loadResources();
            this.initEditor();
            this.script = this._script;
        } catch (error) {
            this.showToast(ERROR_INITIALIZING_SCRIPT_EDITOR, error.body.message);
        }
        this.loading = false;
    }

    get script() {
        return this._script;
    }

    set script(value) {
        this._script = value;
        if(this.script) {
            this.editor?.getDoc()?.setValue(this.script);
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.editor?.refresh(), 1);
        }
    }

    async loadResources() {
        await loadScript(this, CODE_MIRROR + '/codemirror-5.46.0/lib/codemirror.js');
        await loadScript(this, CODE_MIRROR + '/codemirror-5.46.0/addon/lint/lint.js');
        await loadScript(this, CODE_MIRROR + '/codemirror-5.46.0/mode/shell/shell.js');
        await loadStyle(this, CODE_MIRROR + '/codemirror-5.46.0/lib/codemirror.css');
        await loadStyle(this, CODE_MIRROR + '/codemirror-5.46.0/addon/lint/lint.css');
    }

    textArea() {
        const result = document.createElement('textarea');
        result.classList.add('script');
        this.template.querySelector('.container').appendChild(result);
        return result;
    }

    initEditor() {
        // eslint-disable-next-line no-undef
        this.editor = this.editor || CodeMirror.fromTextArea(this.textArea(), {
            lineNumbers: true,
            lineWrapping: true,
            mode: 'text/x-sh',
            readOnly: !this.editMode,
            gutters: ['CodeMirror-lint-markers'],
            lint: true
          });
    }

    async save() {
        await this.quickSave();
        this.editMode = false;
        this.editor.setOption("readOnly", true);
    }

    async quickSave() {
        this.loading = true;

        try {
            await updateRecord(this.record());
            this.showToast(SUCCESS, SCRIPT_UPDATED, 'success');
        } catch(error) {
            this.showToast(ERROR, error.body.message);
        }

        this.loading = false;
    }

    edit() {
        this.editMode = true;
        this.editor.setOption("readOnly", false);
    }

    cancel() {
        this.editMode = false;
        this.editor.setOption("readOnly", true);
        this.editor?.getDoc()?.setValue(this.script);
    }

    record() {
        return {
            fields: {
                Id: this.function.id,
                [SCRIPT.fieldApiName]: this.editor.getValue()
            }
        }; 
    }

    showToast(title, message, variant = 'error') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}