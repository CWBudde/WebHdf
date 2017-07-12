unit Demo.Main;

interface

uses
  WHATWG.Console, WHATWG.XHR, ECMA.TypedArray, W3C.DOM4, W3C.Html5,
  Demo.Framework, HdfFile;

type
  THeader = class(TDivElement)
  private
  public
    procedure AfterConstructor; override;
  end;

  TFileSelect = class(TDivElement)
  private
    FInputFile: TInputFileElement;
  public
    procedure AfterConstructor; override;

    property InputFile: TInputFileElement read FInputFile;
  end;

  TArrayOfString = array of String;

  TMainScreen = class(TDivElement)
  private
    FHeader: THeader;
    FFileSelect: TFileSelect;
    FTextArea: TTextAreaElement;

    procedure AddText(Text: String);
    procedure LoadDefault;
    procedure LoadHdfFile(Buffer: JArrayBuffer);
    procedure PrintFileInformation(HdfFile: THdfFile);
  public
    constructor Create(Owner: IHtmlElementOwner); overload; override;

    procedure Resize(Event: JEvent);
    procedure PrintDataObjectInformation(DataObject: THdfDataObject; Indent: Integer);
  end;

var
  MainScreen: TMainScreen;

implementation

uses
  W3C.FileAPI;

{ THeader }

procedure THeader.AfterConstructor;
begin
  var Heading := TH1Element.Create(Self as IHtmlElementOwner);
  Heading.Text := 'WebHdf Demo';
  Heading.Style.color := '#FFF';
  Heading.Style.TextShadow := '1px 1px 4px rgba(0,0,0,0.75)';
end;


{ TFileSelect }

procedure TFileSelect.AfterConstructor;
begin
  FInputFile := TInputFileElement.Create(Self as IHtmlElementOwner);
end;


{ TMainScreen }

constructor TMainScreen.Create(Owner: IHtmlElementOwner);
begin
  inherited Create(Owner);

  MainScreen := Self;
  DivElement.ID := 'main';

  // Create Header
  FHeader := THeader.Create(Self as IHtmlElementOwner);

  FFileSelect := TFileSelect.Create(Self as IHtmlElementOwner);
  FFileSelect.InputFile.InputElement.addEventListener('change', lambda(Event: JEvent)
      var Files : JFileList = JFileList(Variant(Event.target).files);
      var Reader := JFileReader.Create;
      Reader.onload := lambda
        Console.Log('Loading file ' + JFile(Files[0]).name);
        LoadHdfFile(JArrayBuffer(Reader.result));
        Result := nil;
      end;
      Reader.readAsArrayBuffer(Files[0]);
    end);

  FTextArea := TTextAreaElement.Create(Self as IHtmlElementOwner);
  FTextArea.TextAreaElement.Rows := 20;

  LoadDefault;
end;

procedure TMainScreen.Resize(Event: JEvent);
begin

end;

procedure TMainScreen.LoadDefault;
begin
  var Request := JXMLHttpRequest.Create;
  Request.onload := lambda
    LoadHdfFile(JArrayBuffer(Request.response));
    Result := nil;
  end;
  Request.responseType := 'arraybuffer';
  Request.open('GET', 'default.sofa', true);
  Request.send;
end;

procedure TMainScreen.LoadHdfFile(Buffer: JArrayBuffer);
begin
  var HdfFile := THdfFile.Create;
  try
    HdfFile.LoadFromBuffer(Buffer);
    PrintFileInformation(HdfFile);
  finally
    HdfFile.Free;
  end;
end;

procedure TMainScreen.PrintDataObjectInformation(DataObject: THdfDataObject; Indent: Integer);
var
  Index: Integer;
  IndentStr, Value: string;
begin
  IndentStr := DupeString(' ', Indent);
  if Indent > 2 then
    AddText('');
  AddText(IndentStr + 'Name: ' + DataObject.Name);
  AddText(IndentStr + 'Data Class: ' + IntToStr(DataObject.DataType.DataClass));
  AddText(IndentStr + 'Data Dimensionality: ' + IntToStr(DataObject.DataSpace.Dimensionality));
  if DataObject.DataSpace.Dimensionality > 0 then
  begin
    for Index := 0 to DataObject.DataSpace.Dimensionality - 1 do
      AddText(IndentStr + '  ' + IntToStr(DataObject.DataSpace.Dimension[Index]));
  end;

  if DataObject.AttributeListCount > 0 then
  begin
    AddText(IndentStr + 'Attributes: ');
    for Index := 0 to DataObject.AttributeListCount - 1 do
    begin
      Value := DataObject.AttributeListItem[Index].ValueAsString;
      if Value <> '' then
        AddText(IndentStr + '  ' + DataObject.AttributeListItem[Index].Name + ': ' + Value)
      else
        AddText(IndentStr + '  ' + DataObject.AttributeListItem[Index].Name);
    end;
  end;

  if Assigned(DataObject.Data) then
    AddText(IndentStr + 'Data Size: ' + IntToStr(DataObject.Data.byteLength));

  // write data objects
  if DataObject.DataObjectCount > 0 then
  begin
    AddText(IndentStr + 'Data Objects: ');
    for Index := 0 to DataObject.DataObjectCount - 1 do
      PrintDataObjectInformation(DataObject.DataObject[Index], Indent + 2);
  end;
end;

procedure TMainScreen.PrintFileInformation(HdfFile: THdfFile);
begin
  FTextArea.Value := '';
  AddText('Super block');
  AddText('  Offset size: ' + IntToStr(HdfFile.SuperBlock.OffsetSize));
  AddText('  Lengths size: ' + IntToStr(HdfFile.SuperBlock.LengthsSize));
  AddText('  End of file address: ' + IntToStr(HdfFile.SuperBlock.EndOfFileAddress));
  AddText('');
  PrintDataObjectInformation(HdfFile.DataObject, 2);
end;

procedure TMainScreen.AddText(Text: String);
begin
  FTextArea.Value := FTextArea.Value + Text + #13;
end;

end.