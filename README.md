# VSC-Kendo-Components
This is a VS Code extension which provides completion support in html files for [Kendo UI Components](https://github.com/arthwang/kendoui-components) by which you can use Kendo UI in web component way.

## Features and Usage

### Resource reference snippets

Typing 'html5:kendoui'(not including the quotes) in a html file triggers the skeleton snippet of needed resources for a page using Kendo UI library. {version} in snippet below are the same version numbers of Kendo UI from which this extension is built. Current version is __2020.2.617__.
This extension will try to keep the pace with latest version of Kendo UI. You'd better to refactor your projects to make version consistent with updates of this extension.

~~~html
<!DOCTYPE html>
<html lang='en'>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <meta http-equiv='X-UA-Compatible' content='ie=edge'>
  <title></title>
  <link rel='stylesheet' href='http://kendo.cdn.telerik.com/{vresion}/styles/kendo.common.min.css'/>
  <link rel='stylesheet' href='http://kendo.cdn.telerik.com/{vresion}/styles/kendo.default.min.css'/>
  <link rel='stylesheet' href='http://kendo.cdn.telerik.com/{vresion}/styles/kendo.mobile.all.min.css'/>
  <script src='http://kendo.cdn.telerik.com/{vresion}/js/jquery.min.js'></script>
  <script src='http://kendo.cdn.telerik.com/{vresion}/js/kendo.ui.min.js'></script>
  <script src='/node_modules/kendoui-components/dist/kendo-components.min.js'></script>
</head>
<body>
  
</body>
</html>
~~~
The last line of above snippet refers to kendoui-components package. You can install it by 'npm i --save kendoui-components'.

### Kendo widget tag completions

Typing '<k- ' or '<km- ' (notice the space and no quotes) pops up the component tag names completions list with a brief overview of the widget. 
![demo](images/demo.gif)

### Kendo widget configuration options completions

As shown in above animation, __WHITE SPACE__ followed a component tagname or key=value attribute assignments pops up the corresponding options list of current widget with types or signatures descriptions for properties or listeners respectivily.

### Kendo widget option object keys completions

Typing ',' or '{' while inputting value pops up avalible properties if the value is an object, e.g. animation of k-auto-complete.

## [Change Log](CHANGELOG.md)

## [Bug Reporting](https://github.com/arthwang/vsc-kendo-components/issues)

## License

  [MIT](http://www.opensource.org/licenses/mit-license.php)