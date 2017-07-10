unit Main;

uses
  WHATWG.Console, WHATWG.XHR, ECMA.TypedArray, HdfFile;

procedure LoadHdfFile(Buffer: JArrayBuffer);
begin
  var HdfFile := THdfFile.Create;
  try
    HdfFile.LoadFromBuffer(Buffer);
  finally
    HdfFile.Free;
  end;
end;

var Request := JXMLHttpRequest.Create;
Request.onload := lambda
  LoadHdfFile(JArrayBuffer(Request.response));
  Result := nil;
end;
Request.responseType := 'arraybuffer';
Request.open('GET', 'default.sofa', true);
Request.send;
