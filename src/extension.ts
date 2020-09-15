"use strict";
// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from "vscode";
import * as os from "os";

import KendoCompletionItemProvider from './features/kendoCompletionItemProvider';
import AttributeFormatter from "./features/attributeFormatter";


export function activate(context: vscode.ExtensionContext) {
  console.log('Congratulations, your extension "vsc-kendo-core-components" is now active!');
  const HTML_MODE: vscode.DocumentFilter = { language: "html", scheme: "file" };

  context.subscriptions.push(vscode.languages.registerCompletionItemProvider(HTML_MODE, new KendoCompletionItemProvider(context), ' ', '+', '\n', '{', ','));

  vscode.workspace.onWillSaveTextDocument(AttributeFormatter.formatAttributes);
}

// this method is called when your extension is deactivated
export function deactivate() { }
