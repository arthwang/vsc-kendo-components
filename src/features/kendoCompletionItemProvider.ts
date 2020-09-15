import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

interface IKendoTag {
  [title: string]: {
    prefix: string;
    body: string;
    description: string;
  }
}
export default class KendoCompletionItemProvider implements vscode.CompletionItemProvider {
  private _kendoCore = null;
  // private _kendoTagCompletions: vscode.CompletionItem[];
  private _mobileTagCompletions: vscode.CompletionItem[];
  private _nonMobileTagCompletions: vscode.CompletionItem[];

  private _kendoTags = null

  constructor(context: vscode.ExtensionContext) {
    const kendoCoreJson = path.resolve(__dirname, 'kendoui.json');
    this._kendoCore = JSON.parse(fs.readFileSync(kendoCoreJson).toString());
    const kendoTagsJson = path.resolve(context.extensionPath, 'snippets/kendoui_tags.json');
    this._kendoTags = JSON.parse(fs.readFileSync(kendoTagsJson).toString());
    this._genTagCompletionItems(this._kendoTags);
  }
  private _childInterfaceType(parentTypeStr: string, childKey?: string) {
    const index = parentTypeStr.indexOf("kendo.");
    if (index > -1) {
      const pType = parentTypeStr.slice(index);
      const intrf = eval(`this._kendoCore.${pType}`);
      return childKey ? intrf[childKey] : intrf;
    } else {
      return null;
    }
  }
  private _entryToCompletionItem(entry) {
    const completionItem = new vscode.CompletionItem(`${entry[1].prefix}(${entry[0]})`, vscode.CompletionItemKind.Text);
    completionItem.detail = entry[1].description;
    completionItem.insertText = new vscode.SnippetString(entry[1].body);
    return completionItem;
  }
  private _genTagCompletionItems(tagsObj: IKendoTag) {
    const mobileTags = Object.entries(tagsObj).filter(function (entry) {
      return entry[0].startsWith('Mobile');
    });
    const nonMobileTags = Object.entries(tagsObj).filter(function (entry) {
      return !entry[0].startsWith('Mobile');
    });
    this._mobileTagCompletions = mobileTags.map(entry => this._entryToCompletionItem(entry));
    this._nonMobileTagCompletions = nonMobileTags.map(entry => this._entryToCompletionItem(entry));
  }

  private _hyphenatedName(pascalName: string): string {
    return pascalName.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase();

  }
  public provideCompletionItems(
    doc: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken
  ): vscode.CompletionItem[] | null {
    const range: vscode.Range = new vscode.Range(new vscode.Position(0, 0), position);
    let text = doc.getText(range);
    if (text.endsWith('<k- ')) {
      this._nonMobileTagCompletions.forEach(item => {
        item.additionalTextEdits = [vscode.TextEdit.delete(new vscode.Range(position.line, position.character - 4, position.line, position.character))];
      })
      return this._nonMobileTagCompletions;
    }
    if (text.endsWith('<km- ')) {
      this._mobileTagCompletions.forEach(item => {
        item.additionalTextEdits = [vscode.TextEdit.delete(new vscode.Range(position.line, position.character - 5, position.line, position.character))];
      })
      return this._mobileTagCompletions;
    }

    const kreg = /<km?-\w+/g;
    let kmatch = null, lastIdx = null;
    while (kmatch = kreg.exec(text)) {
      lastIdx = kmatch.index;
    }

    text = text.slice(lastIdx);
    if (/<(km?-[\w-]+)[\s\S]*<\/\1>/m.test(text)) {
      return [];
    }

    const tagReg = /<(km?-[\w-]+)((\s+[\w-]+(=("[\s\S]*?"|'[\s\S]*?'|[\w\d\.\-]*))?)*)\s+(([\w-]+)=('[\s\S]*(?!')|"[\s\S]*(?!"))[{,])?$/m;

    const tagMatch = text.match(tagReg);

    if (tagMatch) {
      const widgetName = tagMatch[1].startsWith('km-') ? 'mobile' + tagMatch[1].slice(2) : tagMatch[1].slice(2);
      const pascalName = widgetName
        .split('-')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join('');
      let optionsKey = `this._kendoCore.${this._kendoCore["options"][pascalName]}`;

      let optionsArray = null;
      let objPropPath = null;

      if (tagMatch[6]) {
        const re = /\b[\w-]+(?=:\{)/g;
        objPropPath = tagMatch[6];
        const siblingRe = /\s*[\w-]+\s*:\s*(\{[\s\S]*?\}|'[\s\S]*?'|"[\s\S]*?"|\w+)\s*,/mg;
        objPropPath = objPropPath.replace(siblingRe, '');

        let m = objPropPath.match(re);
        optionsKey += `["${tagMatch[7]}"]`;
        const propType = eval(optionsKey);
        let props;
        if (m) {
          props = m.reduce((propType, child) => this._childInterfaceType(propType, child), propType);
          props = this._childInterfaceType(props);
        } else {
          props = this._childInterfaceType(propType);
        }
        optionsArray = Object.entries(props);
      } else {
        const propsSetRe = /[\w-]+(?==)/g;
        const propsMatch = tagMatch[2].match(propsSetRe);
        optionsArray = Object.entries(eval(optionsKey)).map(entry => [this._hyphenatedName(entry[0]), entry[1]]);

        const rangeLater = new vscode.Range(position, doc.positionAt(doc.getText().length - 1));
        const textLater = doc.getText(rangeLater);
        const propsLater = textLater.slice(0, textLater.indexOf('>'));
        const propsMatchLater = propsLater.match(propsSetRe);
        let allProps = [];
        if (propsMatch) {
          allProps = [...propsMatch];
        }
        if (propsMatchLater) {
          allProps = [...allProps, ...propsMatchLater];
        }
        if (allProps.length > 0) {
          optionsArray = optionsArray.filter(entry =>
            allProps.indexOf(entry[0]) === -1
          );
        }

      }
      if (!optionsArray) {
        return [];
      }
      const completionItems = optionsArray.map(item => {
        const citem = new vscode.CompletionItem(item[0], vscode.CompletionItemKind.Text);
        citem.detail = item[1].toString();
        citem.insertText = new vscode.SnippetString(item[0] + (objPropPath ? ':$0' : "=$0"));
        return citem;
      })
      return completionItems;
    }
    return null;

  }

}