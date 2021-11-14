#include "DataWharf.ch"
memvar oFcgi

//=================================================================================================================
function DataDictionaryVisualizeBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
local l_cHtml := []
local l_oDB1
local l_oData
local l_cSitePath := oFcgi:RequestSettings["SitePath"]
local l_cNodePositions := ""
local l_hNodePositions := {=>}
local l_nLengthDecoded
local l_hCoordinate
local l_iNumberOfNameSpaces
local l_cNodeLabel
local l_iDiagram_pk

// See https://visjs.github.io/vis-network/examples/

l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)

With Object l_oDB1

    :Table("Diagram")
    :Column("Diagram.pk"     ,"Diagram_pk")
    :Column("Diagram.VisPos" ,"Diagram_VisPos")
    :Where("Diagram.fk_Application = ^" , par_iApplicationPk)
    :SQL("ListOfDiagrams")

    if :Tally > 0
        l_iDiagram_pk    := ListOfDiagrams->Diagram_pk
        l_cNodePositions := ListOfDiagrams->Diagram_VisPos
    else
        l_cNodePositions := ""
        l_iDiagram_pk    := 0
    endif

    // :Table("Application")
    // :Column("Application.VisPos","Application_VisPos")
    // l_oData := :Get(par_iApplicationPk)
    // if :Tally == 1
    //     l_cNodePositions := l_oData:Application_VisPos
    // endif

endwith

l_nLengthDecoded := hb_jsonDecode(l_cNodePositions,@l_hNodePositions)

With Object l_oDB1
    :Table("NameSpace")
    :Distinct(.t.)
    :Column("NameSpace.Name"   ,"NameSpace_Name")
    :Where("NameSpace.fk_Application = ^",par_iApplicationPk)
    :SQL()
    l_iNumberOfNameSpaces := :Tally

    :Table("Table")
    :Column("Table.pk"         ,"pk")
    :Column("NameSpace.Name"   ,"NameSpace_Name")
    :Column("Table.Name"       ,"Table_Name")
    :Column("Table.Status"     ,"Table_Status")
    :Column("Table.Description","Table_Description")
    :Column("Upper(NameSpace.Name)","tag1")
    :Column("Upper(Table.Name)","tag2")
    :Join("inner","NameSpace","","Table.fk_NameSpace = NameSpace.pk")
    :Where("NameSpace.fk_Application = ^",par_iApplicationPk)
    :SQL("ListOfTables")

endwith

// l_cHtml += '<script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>'

l_cHtml += [<script language="javascript" type="text/javascript" src="]+l_cSitePath+[scripts/vis_2021_11_11_001/vis-network.min.js"></script>]

l_cHtml += [<style type="text/css">]
l_cHtml += [  #mynetwork {]
l_cHtml += [    width: 1200px;]
l_cHtml += [    height: 800px;]
l_cHtml += [    border: 1px solid lightgray;]
l_cHtml += [  }]
l_cHtml += [</style>]


l_cHtml += [<form action="" method="post" name="form" enctype="multipart/form-data">]
l_cHtml += [<input type="hidden" name="formname" value="Design">]
l_cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]
l_cHtml += [<input type="hidden" id="TextNodePositions" name="TextNodePositions" value="">]
l_cHtml += [<input type="hidden" id="TextDiagramPk" name="TextDiagramPk" value="]+Trans(l_iDiagram_pk)+[">]





l_cHtml += [<nav class="navbar navbar-light bg-light">]
    l_cHtml += [<div class="input-group">]
        // l_cHtml += [<input type="button" class="btn btn-primary rounded me-3" value="Save" onclick="$('#ActionOnSubmit').val('Save');document.form.submit();" role="button">]
        // l_cHtml += [<input type="button" class="btn btn-primary rounded me-3" value="Cancel" onclick="$('#ActionOnSubmit').val('Cancel');document.form.submit();" role="button">]

        //---------------------------------------------------------------------------
        l_cHtml += [<button class="btn btn-primary rounded ms-3 me-3" onclick="]

        l_cHtml += [network.storePositions();]

        //Since the redraw() fails to make the edges straight, need to actually submit the entire form.
        // l_cHtml += [$.ajax({]
        // l_cHtml += [  type: 'GET',]
        // l_cHtml += [  url: ']+l_cSitePath+[ajax/VisualizationPositions',]
        // l_cHtml += [  data: 'apppk=]+Trans(par_iApplicationPk)+[&pos='+JSON.stringify(network.getPositions()),]
        // l_cHtml += [  cache: false ]
        // l_cHtml += [});]

        l_cHtml += [$('#TextNodePositions').val( JSON.stringify(network.getPositions()) );]
        l_cHtml += [$('#ActionOnSubmit').val('Save');document.form.submit();]

        // l_cHtml += [alert('step 1');]
        // l_cHtml += [network.redraw();]
        // l_cHtml += [network.stabilize();]
        // l_cHtml += [alert('step 2');]

        // l_cHtml += [return true;]

        
        //Code used to debug the positions.
        l_cHtml += [">Save Layout</button>]

        //---------------------------------------------------------------------------

        l_cHtml += [<button class="btn btn-primary rounded me-3" onclick="]
        
        // l_cHtml += [$.ajax({]
        // l_cHtml += [  type: 'GET',]
        // l_cHtml += [  url: ']+l_cSitePath+[ajax/VisualizationPositions',]
        // l_cHtml += [  data: 'apppk=]+Trans(par_iApplicationPk)+[&pos=reset',]
        // l_cHtml += [  cache: false ]
        // l_cHtml += [});]

        //Code used to debug the positions.
        l_cHtml += [$('#TextNodePositions').val( JSON.stringify(network.getPositions()) );]
        l_cHtml += [$('#ActionOnSubmit').val('Reset');document.form.submit();]

        l_cHtml += [">Reset Layout</button>]
        //---------------------------------------------------------------------------


    l_cHtml += [</div>]
l_cHtml += [</nav>]




l_cHtml += [<table><tr>]
//-------------------------------------
l_cHtml += [<td valign="top">]
l_cHtml += [<div id="mynetwork"></div>]
l_cHtml += [</td>]
//-------------------------------------
l_cHtml += [<td valign="top">]
l_cHtml += [<div id="GraphInfo"></div>]
l_cHtml += [</td>]
//-------------------------------------
l_cHtml += [</tr></table>]



//Code used to debug the positions.
// l_cHtml += [<div><input type="text" name="TextNodePositions" id="TextNodePositions" size="100" value=""></div>]

l_cHtml += [</form>]

l_cHtml += [<script type="text/javascript">]

l_cHtml += [var network;]

l_cHtml += [function MakeVis(){]

// create an array with nodes
l_cHtml += 'var nodes = new vis.DataSet(['
select ListOfTables
scan all
    if l_iNumberOfNameSpaces == 1
        l_cNodeLabel := AllTrim(ListOfTables->Table_Name)
    else
        l_cNodeLabel := AllTrim(ListOfTables->NameSpace_Name)+"\n"+AllTrim(ListOfTables->Table_Name)
    endif
    l_cHtml += [{id:]+Trans(ListOfTables->pk)+[,label:"]+l_cNodeLabel+["]

    if ListOfTables->Table_Status >= 4
        l_cHtml += [,color:{background:'#ff9696',highlight:{background:'#feb4b4'}}]
    endif

    if l_nLengthDecoded > 0
        l_hCoordinate := hb_HGetDef(l_hNodePositions,Trans(ListOfTables->pk),{=>})
        if len(l_hCoordinate) > 0
            l_cHtml += [,x:]+Trans(l_hCoordinate["x"])+[,y:]+Trans(l_hCoordinate["y"])
        endif
    endif
    l_cHtml += [},]
endscan
l_cHtml += ']);'

// create an array with edges
With Object l_oDB1
    :Table("Table")
    :Column("Table.pk"               ,"pkFrom")
    :Column("Column.fk_TableForeign" ,"pkTo")
    :Column("Column.Status"          ,"Column_Status")
    :Column("Column.pk"              ,"Column_Pk")
    :Join("inner","NameSpace","","Table.fk_NameSpace = NameSpace.pk")
    :Join("inner","Column","","Column.fk_Table = Table.pk")
    :Where("NameSpace.fk_Application = ^",par_iApplicationPk)
    :Where("Column.fk_TableForeign <> 0")
    :SQL("ListOfLinks")
endwith

l_cHtml += 'var edges = new vis.DataSet(['

select ListOfLinks
scan all
    l_cHtml += [{id:"]+Trans(ListOfLinks->Column_Pk)+[",from:]+Trans(ListOfLinks->pkFrom)+[,to:]+Trans(ListOfLinks->pkTo)+[,arrows:"from"]
    if ListOfLinks->Column_Status >= 4
        l_cHtml += [,color:{color:'#ff6b6b',highlight:'#ff3e3e'}]
    endif
    l_cHtml += [},]  //,physics: false , smooth: { type: "cubicBezier" }
endscan

l_cHtml += ']);'

// create a network
l_cHtml += [  var container = document.getElementById("mynetwork");]
l_cHtml += [  var data = {]
l_cHtml += [    nodes: nodes,]
l_cHtml += [    edges: edges,]
l_cHtml += [  };]
l_cHtml += [  var options = {nodes:{shape:"box",margin:12,physics:false},]
l_cHtml +=                  [edges:{physics:false},};]
l_cHtml += [  network = new vis.Network(container, data, options);]  //var

l_cHtml += ' network.on("click", function (params) {'
l_cHtml += '   params.event = "[original event]";'

l_cHtml += '   $("#GraphInfo" ).load( "'+l_cSitePath+'ajax/GetInfo","info="+JSON.stringify(params) );'

l_cHtml += '      });'

l_cHtml += [};]

l_cHtml += [</script>]

oFcgi:p_cjQueryScript += [MakeVis();]


return l_cHtml
//=================================================================================================================
function DataDictionaryVisualizeOnSubmit(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
local l_cHtml := []
local l_cActionOnSubmit := oFcgi:GetInputValue("ActionOnSubmit")
local l_cNodePositions
local l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_iDiagram_pk

l_iDiagram_pk := Val(oFcgi:GetInputValue("TextDiagramPk"))

do case
case l_cActionOnSubmit == "Save"
    l_cNodePositions  := Strtran(SanitizeInput(oFcgi:GetInputValue("TextNodePositions")),[%22],["])

    With Object l_oDB1
        :Table("Diagram")
        :Field("VisPos",l_cNodePositions)
        if empty(l_iDiagram_pk)
            //Add an initial Diagram File
            :Field("fk_Application" ,par_iApplicationPk)
            :Field("Name"           ,"All Tables")
            :Field("Status"         ,1)
            if :Add()
                l_iDiagram_pk := :Key()
            endif
        else
            :Update(l_iDiagram_pk)
        endif
    endwith

case l_cActionOnSubmit == "Reset"
    With Object l_oDB1
        :Table("Diagram")
        :Field("VisPos","")
        if empty(l_iDiagram_pk)
            //Add an initial Diagram File
            :Field("fk_Application" ,par_iApplicationPk)
            :Field("Name"           ,"All Tables")
            :Field("Status"         ,1)
            if :Add()
                l_iDiagram_pk := :Key()
            endif
        else
            :Update(l_iDiagram_pk)
        endif
    endwith

endcase

l_cHtml += DataDictionaryVisualizeBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
return l_cHtml
//=================================================================================================================
// The Following function was used by deprecated Ajax Call
// function SaveVisualizationPositions()

// local l_iApplicationPk := val(oFcgi:GetQueryString("apppk"))
// local l_cNodePositions := Strtran(oFcgi:GetQueryString("pos"),[%22],["])

// local l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)

// With Object l_oDB1
//     :Table("Application")
//     :Field("VisPos",l_cNodePositions)
//     :Update(l_iApplicationPk)
// endwith

// return ""
//=================================================================================================================
function GetInfoDuringVisualization()
local l_cHtml := []
local l_cInfo := Strtran(oFcgi:GetQueryString("info"),[%22],["])
local l_hOnClickInfo := {=>}
local l_nLengthDecoded
local l_aNodes
local l_aEdges
local l_iTablePk
local l_iColumnPk
local l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oData
local l_aSQLResult := {}
local l_cSitePath := oFcgi:RequestSettings["SitePath"]
local l_cApplicationLinkCode
local l_cNameSpaceName
local l_cTableName
local l_cTableDescription
local l_nTableStatus
local l_cColumnName
local l_nColumnStatus
local l_cFrom_NameSpace_Name
local l_cFrom_Table_Name
local l_cTo_NameSpace_Name
local l_cTo_Table_Name

// l_cHtml += [Hello World c2 - ]+hb_TtoS(hb_DateTime())+[  ]+l_cInfo

l_nLengthDecoded := hb_jsonDecode(l_cInfo,@l_hOnClickInfo)
// Altd()

// if l_hOnClickInfo["nodes"]  is an array. if len is 1 we have the table.pk
// if l_hOnClickInfo["nodes"] is a 0 size array and l_hOnClickInfo["edges"] array of len 1   will be column.pk

l_aNodes := hb_HGetDef(l_hOnClickInfo,"nodes",{})
if len(l_aNodes) == 1
    l_iTablePk := l_aNodes[1]

    //Clicked on a table
    with object l_oDB1
        :Table("Table")
        :Column("Application.LinkCode" ,"Application_LinkCode")
        :Column("NameSpace.name"       ,"NameSpace_Name")
        :Column("Table.Name"           ,"Table_Name")
        :Column("Table.Description"    ,"Table_Description")
        :Column("Table.Status"         ,"Table_Status")
        :join("inner","NameSpace","","Table.fk_NameSpace = NameSpace.pk")
        :join("inner","Application","","NameSpace.fk_Application = Application.pk")
        :Where("Table.pk = ^" , l_iTablePk)
        :SQL(@l_aSQLResult)

        if :Tally == 1
            l_cApplicationLinkCode := AllTrim(l_aSQLResult[1,1])
            l_cNameSpaceName       := AllTrim(l_aSQLResult[1,2])
            l_cTableName           := AllTrim(l_aSQLResult[1,3])
            l_cTableDescription    := nvl(l_aSQLResult[1,4],"")
            l_nTableStatus         := l_aSQLResult[1,5]


            // l_cHtml += [<nav class="navbar navbar-light bg-light">]

            l_cHtml += [<nav class="navbar navbar-light" style="background-color: #]+iif(l_nTableStatus>=4,"feb4b4","d2e5ff")+[;">]
                l_cHtml += [<div class="input-group">]
                    l_cHtml += [<span class="navbar-brand ms-3 me-3">]+l_cNameSpaceName+[.]+l_cTableName+[</span>]
                    if !empty(l_cTableDescription)
                        l_cHtml += [<div>]+TextToHTML(l_cTableDescription)+[</div>]
                    endif
                l_cHtml += [</div>]
            l_cHtml += [</nav>]

            l_cHtml += [<div class="m-3"></div>]

            :Table("Column")
            :Column("Column.pk"             ,"pk")
            :Column("Column.Name"           ,"Column_Name")
            :Column("Column.Status"         ,"Column_Status")
            :Column("Column.Description"    ,"Column_Description")
            :Column("Column.Order"          ,"Column_Order")
            :Column("Column.Type"           ,"Column_Type")
            :Column("Column.Length"         ,"Column_Length")
            :Column("Column.Scale"          ,"Column_Scale")
            :Column("Column.Nullable"       ,"Column_Nullable")
            :Column("Column.UsedBy"         ,"Column_UsedBy")
            :Column("Column.fk_TableForeign","Column_fk_TableForeign")
            :Column("Column.fk_Enumeration" ,"Column_fk_Enumeration")

            :Column("NameSpace.Name"                ,"NameSpace_Name")
            :Column("Table.Name"                    ,"Table_Name")
            :Column("Enumeration.Name"              ,"Enumeration_Name")
            :Column("Enumeration.ImplementAs"       ,"Enumeration_ImplementAs")
            :Column("Enumeration.ImplementLength"   ,"Enumeration_ImplementLength")
            
            :Join("left","Table"      ,"","Column.fk_TableForeign = Table.pk")
            :Join("left","NameSpace"  ,"","Table.fk_NameSpace = NameSpace.pk")
            :Join("left","Enumeration","","Column.fk_Enumeration  = Enumeration.pk")
            :Where("Column.fk_Table = ^",l_iTablePk)
            :OrderBy("Column_Order")
            :SQL("ListOfColumns")

            if :Tally > 0
                l_cHtml += [<div class="m-2">]

                    select ListOfColumns

                    l_cHtml += [<div class="row justify-content-center">]
                        l_cHtml += [<div class="col-auto">]

                            l_cHtml += [<table class="table table-sm table-bordered table-striped">]

                            l_cHtml += [<tr class="bg-info">]
                                l_cHtml += [<th class="GridHeaderRowCells text-white">Name</th>]
                                l_cHtml += [<th class="GridHeaderRowCells text-white">Type</th>]
                                l_cHtml += [<th class="GridHeaderRowCells text-white">Nullable</th>]
                                l_cHtml += [<th class="GridHeaderRowCells text-white">Foreign Key To</th>]
                                l_cHtml += [<th class="GridHeaderRowCells text-white">Description</th>]
                                l_cHtml += [<th class="GridHeaderRowCells text-white text-center">Status</th>]
                                l_cHtml += [<th class="GridHeaderRowCells text-white">Used By</th>]
                            l_cHtml += [</tr>]

                            scan all
                                l_cHtml += [<tr>]

                                    // Name
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += [<a target="_blank" href="]+l_cSitePath+[Applications/EditColumn/]+l_cApplicationLinkCode+"/"+l_cNameSpaceName+"/"+l_cTableName+[/]+Allt(ListOfColumns->Column_Name)+[/">]+Allt(ListOfColumns->Column_Name)+[</a>]
                                    l_cHtml += [</td>]

                                    // Type
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += FormatColumnTypeInfo(allt(ListOfColumns->Column_Type),;
                                                                        ListOfColumns->Column_Length,;
                                                                        ListOfColumns->Column_Scale,;
                                                                        ListOfColumns->Enumeration_Name,;
                                                                        ListOfColumns->Enumeration_ImplementAs,;
                                                                        ListOfColumns->Enumeration_ImplementLength,;
                                                                        l_cSitePath,;
                                                                        l_cApplicationLinkCode,;
                                                                        l_cNameSpaceName)
                                    l_cHtml += [</td>]

                                    // Nullable
                                    l_cHtml += [<td class="GridDataControlCells text-center" valign="top">]
                                        l_cHtml += iif(alltrim(ListOfColumns->Column_Nullable) == "1",[<i class="fas fa-check"></i>],[&nbsp;])
                                    l_cHtml += [</td>]

                                    // Foreign Key To
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        if !hb_isNil(ListOfColumns->Table_Name)
                                            l_cHtml += [<a style="color:#]+COLOR_ON_LINK_NEWPAGE+[ !important;" target="_blank" href="]+l_cSitePath+[Applications/ListColumns/]+l_cApplicationLinkCode+"/"+ListOfColumns->NameSpace_Name+"/"+ListOfColumns->Table_Name+[/">]
                                            l_cHtml += ListOfColumns->NameSpace_Name+[.]+ListOfColumns->Table_Name
                                            l_cHtml += [</a>]
                                        endif
                                    l_cHtml += [</td>]

                                    // Description
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += TextToHtml(hb_DefaultValue(ListOfColumns->Column_Description,""))
                                    l_cHtml += [</td>]

                                    // Status
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += {"Unknown","Active","Inactive (Read Only)","Archived (Read Only and Hidden)"}[iif(vfp_between(ListOfColumns->Column_Status,1,4),ListOfColumns->Column_Status,1)]
                                        // 1 = Unknown, 2 = Active, 3 = Inactive (Read Only), 4 = Archived (Read Only and Hidden)
                                    l_cHtml += [</td>]

                                    // Used By
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += GetItemInListAtPosition(ListOfColumns->Column_UsedBy,{"All Servers","MySQL Only","PostgreSQL Only"},"")
                                    l_cHtml += [</td>]

                                l_cHtml += [</tr>]
                            endscan
                            l_cHtml += [</table>]
                            
                        l_cHtml += [</div>]
                    l_cHtml += [</div>]

                l_cHtml += [</div>]
            endif


        endif
    endwith

else
    l_aEdges := hb_HGetDef(l_hOnClickInfo,"edges",{})
    if len(l_aEdges) == 1
        l_iColumnPk := l_aEdges[1]

        with object l_oDB1
            :Table("Column")

            :Column("Column.Name  "    ,"Column_Name")
            :Column("Column.Status"    ,"Column_Status")
            
            :Column("NameSpace.Name"   ,"From_NameSpace_Name")
            :Column("Table.Name"       ,"From_Table_Name")
            :join("inner","Table"      ,"","Column.fk_Table = Table.pk")
            :join("inner","NameSpace"  ,"","Table.fk_NameSpace = NameSpace.pk")
            :join("inner","Application","","NameSpace.fk_Application = Application.pk")

            :Column("NameSpaceTo.name" , "To_NameSpace_Name")
            :Column("TableTo.name"     , "To_Table_Name")
            :Join("inner","Table"    ,"TableTo"    ,"Column.fk_TableForeign = TableTo.pk")
            :Join("inner","NameSpace","NameSpaceTo","TableTo.fk_NameSpace = NameSpaceTo.pk")
            
            :Where("Column.pk = ^" , l_iColumnPk)
            :SQL(@l_aSQLResult)

            if :Tally == 1

                l_cColumnName          := Alltrim(l_aSQLResult[1,1])
                l_nColumnStatus        := l_aSQLResult[1,2]

                l_cFrom_NameSpace_Name := Alltrim(l_aSQLResult[1,3])
                l_cFrom_Table_Name     := Alltrim(l_aSQLResult[1,4])

                l_cTo_NameSpace_Name   := Alltrim(l_aSQLResult[1,5])
                l_cTo_Table_Name       := Alltrim(l_aSQLResult[1,6])

                l_cHtml += [<nav class="navbar navbar-light" style="background-color: #]+iif(l_nColumnStatus>=4,"feb4b4","d2e5ff")+[;">]
                    l_cHtml += [<div class="input-group">]
                        l_cHtml += [<span class="navbar-brand ms-3 me-3">From: ]+l_cFrom_NameSpace_Name+[.]+l_cFrom_Table_Name+[</span>]
                        l_cHtml += [<span class="navbar-brand ms-3 me-3">To: ]+l_cTo_NameSpace_Name+[.]+l_cTo_Table_Name+[</span>]
                        l_cHtml += [<span class="navbar-brand ms-3 me-3">Column: ]+l_cColumnName+[</span>]
                    l_cHtml += [</div>]
                l_cHtml += [</nav>]

            endif
        endwith

    else
    endif
endif


return l_cHtml
//=================================================================================================================
