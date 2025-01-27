#include "DataWharf.ch"

//=================================================================================================================
function DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,par_iDiagramPk)
local l_cHtml := []
local l_oDB1               := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfTables   := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfDiagrams := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfLinks    := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_cSitePath          := oFcgi:p_cSitePath
local l_cNodePositions
local l_hNodePositions := {=>}
local l_hNodePosition := {=>}
local l_nMinX := 0
local l_nMinY := 0
local l_nLengthDecoded
local l_lAutoLayout := .t.
local l_hCoordinate
local l_cNodeLabel
local l_nNumberOfSelectedTableInDiagram
local l_nNumberOfTableInDiagram
local l_nNumberOfLinksInDiagram
local l_lShowNamespace
local l_cNamespace_Name
local l_oDataDiagram
local l_nNodeDisplayMode
local l_nRenderMode
local l_lNodeShowDescription
local l_nNodeMinHeight
local l_nNodeMaxWidth
local l_cTableDescription
local l_cDiagramInfoScale
local l_nDiagramInfoScale
local l_iDiagramPk

local l_cUserSetting
local l_lThisDiagramOnly := (GetUserSetting("ThisDiagramOnly",par_iDiagramPk) == "T")
local l_iCanvasWidth
local l_iCanvasHeight
local l_lNavigationControl
local l_lUnknownInGray
local l_lNeverShowDescriptionOnHover
local l_cDiagram_LinkUID
local l_cURL
local l_cProtocol
local l_nPort
local l_cJS
local l_hMultiEdgeCounters := {=>}
local l_cMultiEdgeKeyPrevious
local l_cMultiEdgeKey
local l_nMultiEdgeTotalCount
local l_nMultiEdgeCount
local l_cHashKey
local l_cArrowType

oFcgi:TraceAdd("DataDictionaryVisualizeDiagramBuild")

if l_lThisDiagramOnly
    l_cUserSetting := GetUserSetting("CanvasWidth",par_iDiagramPk)
    if empty(l_cUserSetting)
        l_cUserSetting := GetUserSetting("CanvasWidth")
    endif
    l_iCanvasWidth := val(l_cUserSetting)

    l_cUserSetting := GetUserSetting("CanvasHeight",par_iDiagramPk)
    if empty(l_cUserSetting)
        l_cUserSetting := GetUserSetting("CanvasHeight")
    endif
    l_iCanvasHeight := val(l_cUserSetting)

    l_cUserSetting := GetUserSetting("NavigationControl",par_iDiagramPk)
    if empty(l_cUserSetting)
        l_cUserSetting := GetUserSetting("NavigationControl")
    endif
    l_lNavigationControl := (l_cUserSetting == "T")

    l_cUserSetting := GetUserSetting("UnknownInGray",par_iDiagramPk)
    if empty(l_cUserSetting)
        l_cUserSetting := GetUserSetting("UnknownInGray")
    endif
    l_lUnknownInGray := (l_cUserSetting == "T")

    l_cUserSetting := GetUserSetting("NeverShowDescriptionOnHover",par_iDiagramPk)
    if empty(l_cUserSetting)
        l_cUserSetting := GetUserSetting("NeverShowDescriptionOnHover")
    endif
    l_lNeverShowDescriptionOnHover := (l_cUserSetting == "T")
   
    l_cDiagramInfoScale := GetUserSetting("DiagramInfoScale",par_iDiagramPk)
    if empty(l_cDiagramInfoScale)
        l_cDiagramInfoScale := GetUserSetting("DiagramInfoScale")
    endif

else
    l_iCanvasWidth                 := val(GetUserSetting("CanvasWidth"))
    l_iCanvasHeight                := val(GetUserSetting("CanvasHeight"))
    l_lNavigationControl           := (GetUserSetting("NavigationControl") == "T")
    l_lUnknownInGray               := (GetUserSetting("UnknownInGray") == "T")
    l_lNeverShowDescriptionOnHover := (GetUserSetting("NeverShowDescriptionOnHover") == "T")
    l_cDiagramInfoScale            := GetUserSetting("DiagramInfoScale")

endif

//Save current diagram being used by current user in current application
l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)
with object l_oDB1
    :Table("37aa71df-4025-4f88-bd67-29cdee691d33","UserSettingApplication")
    :Column("UserSettingApplication.pk"        ,"pk")
    :Column("UserSettingApplication.fk_Diagram","fk_Diagram")
    :Where("UserSettingApplication.fk_User = ^",oFcgi:p_iUserPk)
    :Where("UserSettingApplication.fk_Application = ^",par_iApplicationPk)
    :SQL("ListOfUserSettingApplication")
    do case
    case :Tally == 0 .or. :Tally > 1
        if :Tally > 1  //Some bad data, simply delete all records. The next time will select  diagram it will be saved properly.
            select ListOfUserSettingApplication
            scan all
                :Delete("f6e73639-7ab3-4a10-bb96-50c60cc7bd14","UserSettingApplication",ListOfUserSettingApplication->pk)
            endscan
        endif

        //Add a new record
        :Table("37aa71df-4025-4f88-bd67-29cdee691d34","UserSettingApplication")
        :Field("UserSettingApplication.fk_Diagram"    ,par_iDiagramPk)
        :Field("UserSettingApplication.fk_User"       ,oFcgi:p_iUserPk)
        :Field("UserSettingApplication.fk_Application",par_iApplicationPk)
        :Add()
    case :Tally == 1
        if ListOfUserSettingApplication->fk_Diagram <> par_iDiagramPk
            :Table("37aa71df-4025-4f88-bd67-29cdee691d35","UserSettingApplication")
            :Field("UserSettingApplication.fk_Diagram",par_iDiagramPk)
            :Update(ListOfUserSettingApplication->pk)
        endif
    endcase
endwith

//See https://github.com/markedjs/marked for the JS library  _M_ Make this generic to be used in other places
oFcgi:p_cHeader += [<script language="javascript" type="text/javascript" src="]+l_cSitePath+[scripts/marked_]+MARKED_SCRIPT_VERSION+[/marked.min.js"></script>]

l_cHtml += [<script type="text/javascript">]
l_cHtml += 'function KeywordSearch(par_cListOfWords, par_cString) {'
l_cHtml += '  const l_aWords_upper = par_cListOfWords.toUpperCase().split(" ").filter(Boolean);'
l_cHtml += '  const l_cString_upper = par_cString.toUpperCase();'
l_cHtml += '  var l_lAllWordsIncluded = true;'
l_cHtml += '  for (var i = 0; i < l_aWords_upper.length; i++) {'
l_cHtml += '    if (!l_cString_upper.includes(l_aWords_upper[i])) {l_lAllWordsIncluded = false;break;};'
l_cHtml += '  }'
l_cHtml += '  return l_lAllWordsIncluded;'
l_cHtml += '}'
l_cHtml += [</script>]

// See https://visjs.github.io/vis-network/examples/


with object l_oDB_ListOfDiagrams
    :Table("44eabf03-8b35-4e96-a128-e9c1bc6168f0","Diagram")
    :Column("Diagram.pk"         ,"Diagram_pk")
    :Column("Diagram.Name"       ,"Diagram_Name")
    :Column("Upper(Diagram.Name)","Tag1")
    :Where("Diagram.fk_Application = ^" , par_iApplicationPk)
    :OrderBy("Tag1")
    :SQL("ListOfDiagrams")
endwith

with object l_oDB1
    if empty(par_iDiagramPk)
        l_iDiagramPk := ListOfDiagrams->Diagram_pk
    else
        l_iDiagramPk := par_iDiagramPk
    endif

    :Table("f8632e51-09a7-4ee7-bc76-517c490f505a","Diagram")
    :Column("Diagram.RenderMode"         ,"Diagram_RenderMode")
    :Column("Diagram.VisPos"             ,"Diagram_VisPos")
    :Column("Diagram.MxgPos"             ,"Diagram_MxgPos")
    :Column("Diagram.NodeDisplayMode"    ,"Diagram_NodeDisplayMode")
    :Column("Diagram.NodeShowDescription","Diagram_NodeShowDescription")
    :Column("Diagram.NodeMinHeight"      ,"Diagram_NodeMinHeight")
    :Column("Diagram.NodeMaxWidth"       ,"Diagram_NodeMaxWidth")
    :Column("Diagram.LinkUID"            ,"Diagram_LinkUID")
    l_oDataDiagram := :Get(l_iDiagramPk)

    l_nRenderMode          := max(1,l_oDataDiagram:Diagram_RenderMode)
    if l_nRenderMode == RENDERMODE_MXGRAPH
        l_cNodePositions := l_oDataDiagram:Diagram_MxgPos
    else
        l_cNodePositions := l_oDataDiagram:Diagram_VisPos
    endif
    l_nNodeDisplayMode     := max(1,l_oDataDiagram:Diagram_NodeDisplayMode)
    l_lNodeShowDescription := l_oDataDiagram:Diagram_NodeShowDescription
    l_nNodeMinHeight       := l_oDataDiagram:Diagram_NodeMinHeight
    l_nNodeMaxWidth        := l_oDataDiagram:Diagram_NodeMaxWidth
    l_cDiagram_LinkUID     := l_oDataDiagram:Diagram_LinkUID

endwith

with object l_oDB_ListOfTables
    //Check if there is at least one record in DiagramTable for the current Diagram
    :Table("66daafd2-9566-43be-85e5-b663682ba88c","DiagramTable")
    :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
    l_nNumberOfSelectedTableInDiagram := :Count()
    
    if l_nNumberOfSelectedTableInDiagram == 0
        // All Tables
        :Table("5ad2a893-e8bd-40e5-8eb0-a6e4bafbbf51","Table")
        :Column("Table.pk"         ,"pk")
        :Column("Namespace.Name"   ,"Namespace_Name")
        :Column("Table.Name"       ,"Table_Name")
        :Column("Table.AKA"        ,"Table_AKA")
        :Column("Table.Unlogged"   ,"Table_Unlogged")
        :Column("Table.UseStatus"  ,"Table_UseStatus")
        :Column("Table.DocStatus"  ,"Table_DocStatus")
        :Column("Table.Description","Table_Description")
        :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
        :Where("Namespace.fk_Application = ^",par_iApplicationPk)
        :SQL("ListOfTables")

    else
        // A subset of Tables
        :Table("545ab66b-9384-4e06-abf3-ce8e529aa6e1","DiagramTable")
        :Distinct(.t.)
        :Column("Table.pk"         ,"pk")
        :Column("Namespace.Name"   ,"Namespace_Name")
        :Column("Table.Name"       ,"Table_Name")
        :Column("Table.AKA"        ,"Table_AKA")
        :Column("Table.Unlogged"   ,"Table_Unlogged")
        :Column("Table.UseStatus"  ,"Table_UseStatus")
        :Column("Table.DocStatus"  ,"Table_DocStatus")
        :Column("Table.Description","Table_Description")
        :Join("inner","Table","","DiagramTable.fk_Table = Table.pk")
        :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
        :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
        :SQL("ListOfTables")
        with object :p_oCursor
            :Index("pk","pk")
            :CreateIndexes()
        endwith

    endif
    l_nNumberOfTableInDiagram := :Tally

    select ListOfTables
    goto top
    l_cNamespace_Name := ListOfTables->Namespace_Name
    locate for ListOfTables->Namespace_Name <> l_cNamespace_Name
    l_lShowNamespace := Found()

endwith

// create an array with edges
with object l_oDB_ListOfLinks
    if l_nNumberOfSelectedTableInDiagram == 0
        // All tables are displayed
        :Table("8fdc0db2-ac61-4d60-95fc-ce435c6a8bac","Table")
        :Column("Table.pk"                 ,"pkFrom")
        :Column("Column.fk_TableForeign"   ,"pkTo")
        :Column("Column.ForeignKeyUse"     ,"Column_ForeignKeyUse")
        :Column("Column.ForeignKeyOptional","Column_ForeignKeyOptional")
        :Column("Column.OnDelete"          ,"Column_OnDelete")
        :Column("Column.UseStatus"         ,"Column_UseStatus")
        :Column("Column.pk"                ,"Column_Pk")
        :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
        :Join("inner","Column","","Column.fk_Table = Table.pk")
        :Where("Namespace.fk_Application = ^",par_iApplicationPk)
        // :Where("Column.fk_TableForeign IS NOT NULL")
        :Where("Column.fk_TableForeign > 0")
        :OrderBy("pkFrom")
        :OrderBy("pkTo")
        :SQL("ListOfLinks")
        l_nNumberOfLinksInDiagram := :Tally

    else
        // _M_ When the Harbour_ORM will add support to CTE could avoid using vfp_seek and delete
        :Table("9f3afcce-5f28-457e-965c-e294cfd628aa","DiagramTable")
        :Distinct(.t.)
        :Column("Table.pk"                 ,"pkFrom")
        :Column("Column.fk_TableForeign"   ,"pkTo")
        :Column("Column.ForeignKeyUse"     ,"Column_ForeignKeyUse")
        :Column("Column.ForeignKeyOptional","Column_ForeignKeyOptional")
        :Column("Column.OnDelete"          ,"Column_OnDelete")
        :Column("Column.UseStatus"         ,"Column_UseStatus")
        :Column("Column.pk"                ,"Column_Pk")
        :Join("inner","Table"    ,"","DiagramTable.fk_Table = Table.pk")
        :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
        :Join("inner","Column"   ,"","Column.fk_Table = Table.pk")
        :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
        // :Where("Column.fk_TableForeign IS NOT NULL")
        :Where("Column.fk_TableForeign > 0")
        :OrderBy("pkFrom")
        :OrderBy("pkTo")
        :SQL("ListOfLinks")

        //Reduce the list
        l_nNumberOfLinksInDiagram := 0
        select ListOfLinks
        scan all
            if vfp_seek(ListOfLinks->pkTo,"ListOfTables","pk")
                l_nNumberOfLinksInDiagram++
            else
                dbDelete()
            endif
        endscan
        // ExportTableToHtmlFile("ListOfTables",OUTPUT_FOLDER+hb_ps()+"PostgreSQL_ListOfTables.html","From PostgreSQL",,200,.t.)
        // ExportTableToHtmlFile("ListOfLinks" ,OUTPUT_FOLDER+hb_ps()+"PostgreSQL_ListOfLinks.html" ,"From PostgreSQL",,200,.t.)
    endif
endwith

// l_cHtml += '<script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>'

if l_iCanvasWidth < CANVAS_WIDTH_MIN .or. l_iCanvasWidth > CANVAS_WIDTH_MAX
    l_iCanvasWidth := CANVAS_WIDTH_DEFAULT
endif

if l_iCanvasHeight < CANVAS_HEIGHT_MIN .or. l_iCanvasHeight > CANVAS_HEIGHT_MAX
    l_iCanvasHeight := CANVAS_HEIGHT_DEFAULT
endif

// if GRAPH_LIB_DD == "mxgraph"
if l_nRenderMode == RENDERMODE_MXGRAPH
    oFcgi:p_cHeader += [<link rel="stylesheet" type="text/css" href="]+l_cSitePath+[scripts/mxgraph_]+MXGRAPH_SCRIPT_VERSION+[/css/common.css">]
    oFcgi:p_cHeader += [<script language="javascript" type="text/javascript" src="]+l_cSitePath+[scripts/mxgraph_]+MXGRAPH_SCRIPT_VERSION+[/mxClient.js"></script>]
//elseif GRAPH_LIB_DD == "visjs"
else
    oFcgi:p_cHeader += [<script language="javascript" type="text/javascript" src="]+l_cSitePath+[scripts/vis_]+VISJS_SCRIPT_VERSION+[/vis-network.min.js"></script>]
endif

oFcgi:p_cHeader += [<script language="javascript" type="text/javascript" src="]+l_cSitePath+[scripts/DataWharf_]+DATAWHARF_SCRIPT_VERSION+[/visualization.js"></script>]

l_cHtml += [<style type="text/css">]

l_cHtml += [  #mynetwork {]
l_cHtml += [    width: ]+Trans(l_iCanvasWidth)+[px;]
l_cHtml += [    height: ]+Trans(l_iCanvasHeight)+[px;]
l_cHtml += [    border: 1px solid lightgray;]
l_cHtml += [  }]

l_cHtml += [ .tooltip-inner {max-width: 700px;opacity: 1.0;background-color: #198754;} ]
l_cHtml += [ .tooltip.show {opacity:1.0} ]

l_cHtml += [</style>]

l_cHtml += [<form action="" method="post" name="form" enctype="multipart/form-data">]
l_cHtml += [<input type="hidden" name="formname" value="Design">]
l_cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]
l_cHtml += [<input type="hidden" id="TextNodePositions" name="TextNodePositions" value="">]
l_cHtml += [<input type="hidden" id="TextDiagramPk" name="TextDiagramPk" value="]+Trans(l_iDiagramPk)+[">]

l_cHtml += [<nav class="navbar navbar-light bg-light">]
    l_cHtml += [<div class="input-group">]
        //---------------------------------------------------------------------------
        if oFcgi:p_nAccessLevelDD >= 4
            l_cHtml += [<input type="button" role="button" value="Save Layout" id="ButtonSaveLayout" class="btn btn-primary rounded ms-3" onclick="]


            //Since the redraw() fails to make the edges straight, need to actually submit the entire form.
            // l_cHtml += [$.ajax({]
            // l_cHtml += [  type: 'GET',]
            // l_cHtml += [  url: ']+l_cSitePath+[ajax/VisualizationPositions',]
            // l_cHtml += [  data: 'apppk=]+Trans(par_iApplicationPk)+[&pos='+JSON.stringify(network.getPositions()),]
            // l_cHtml += [  cache: false ]
            // l_cHtml += [});]

            // if GRAPH_LIB_DD == "mxgraph"
            if l_nRenderMode == RENDERMODE_MXGRAPH
                l_cHtml += [$('#TextNodePositions').val( JSON.stringify(getPositions(network)) );]
            // elseif GRAPH_LIB_DD == "visjs"
            else
                l_cHtml += [network.storePositions();]
                l_cHtml += [$('#TextNodePositions').val( JSON.stringify(network.getPositions()) );]
            endif
            l_cHtml += [$('#ActionOnSubmit').val('SaveLayout');document.form.submit();]

            //Code used to debug the positions.
            l_cHtml += [">]
        endif
        //---------------------------------------------------------------------------
        // l_cHtml += [<input type="button" role="button" value="Reset Layout" class="btn btn-primary rounded me-3" onclick="]
        
        // // l_cHtml += [$.ajax({]
        // // l_cHtml += [  type: 'GET',]
        // // l_cHtml += [  url: ']+l_cSitePath+[ajax/VisualizationPositions',]
        // // l_cHtml += [  data: 'apppk=]+Trans(par_iApplicationPk)+[&pos=reset',]
        // // l_cHtml += [  cache: false ]
        // // l_cHtml += [});]

        // //Code used to debug the positions.
        // l_cHtml += [$('#TextNodePositions').val( JSON.stringify(network.getPositions()) );]
        // l_cHtml += [$('#ActionOnSubmit').val('ResetLayout');document.form.submit();]

        // l_cHtml += [">]
        //---------------------------------------------------------------------------
        if oFcgi:p_nAccessLevelDD >= 4
             l_cHtml += [<input type="button" role="button" value="Diagram Settings" class="btn btn-primary rounded ms-3" onclick="$('#ActionOnSubmit').val('DiagramSettings');document.form.submit();">]
        endif
        //---------------------------------------------------------------------------
         l_cHtml += [<select id="ComboDiagramPk" name="ComboDiagramPk" onchange="$('#TextDiagramPk').val(this.value);$('#ActionOnSubmit').val('Show');document.form.submit();" class="ms-3">]

            select ListOfDiagrams
            scan all
                l_cHtml += [<option value="]+Trans(ListOfDiagrams->Diagram_Pk)+["]+iif(ListOfDiagrams->Diagram_Pk == l_iDiagramPk,[ selected],[])+[>]+ListOfDiagrams->Diagram_Name+[</option>]
            endscan
         l_cHtml += [</select>]
        //---------------------------------------------------------------------------
        if oFcgi:p_nAccessLevelDD >= 4
             l_cHtml += [<input type="button" role="button" value="New Diagram" class="btn btn-primary rounded ms-3" onclick="$('#ActionOnSubmit').val('NewDiagram');document.form.submit();">]
             l_cHtml += [<input type="button" role="button" value="Duplicate" class="btn btn-primary rounded ms-3" onclick="$('#ActionOnSubmit').val('DuplicateDiagram');document.form.submit();">]
        endif
        //---------------------------------------------------------------------------
         l_cHtml += [<input type="button" role="button" value="My Settings" class="btn btn-primary rounded ms-3" onclick="$('#ActionOnSubmit').val('MyDiagramSettings');document.form.submit();">]
        //---------------------------------------------------------------------------

        //Get the current URL and add a reference to the current diagram LinkUID
        l_cProtocol := oFcgi:RequestSettings["Protocol"]
        l_nPort     := oFcgi:RequestSettings["Port"]
        l_cURL := l_cProtocol+"://"+oFcgi:RequestSettings["Host"]
        if !((l_cProtocol == "http" .and. l_nPort == 80) .or. (l_cProtocol == "https" .and. l_nPort == 443))
            l_cURL += ":"+Trans(l_nPort)
        endif
        l_cURL += oFcgi:p_cSitePath
        l_cURL += oFcgi:RequestSettings["Path"]
        l_cURL += [?InitialDiagram=]+l_cDiagram_LinkUID

        l_cHtml += [<input type="button" role="button" value="Copy Diagram Link To Clipboard" class="btn btn-primary rounded ms-3" id="CopyLink" onclick="]
        
        l_cHtml += [navigator.clipboard.writeText(']+l_cURL+[').then(function() {]
        l_cHtml += [$('#CopyLink').addClass('btn-success').removeClass('btn-primary');]
        l_cHtml += [}, function() {]
        l_cHtml += [$('#CopyLink').addClass('btn-danger').removeClass('btn-primary');]
        l_cHtml += [});]

        l_cHtml += [;return false;">]
        //---------------------------------------------------------------------------
        l_cHtml += [<span class="navbar-text ms-3">]
        l_cHtml += [Tables: ]+trans(l_nNumberOfTableInDiagram)
        l_cHtml += [ - Links: ]+trans(l_nNumberOfLinksInDiagram)
        // l_cHtml += [ - DiagramPk: ]+trans(l_iDiagramPk)
        // l_cHtml += [ - DiagramLinkId: ]+l_oDataDiagram:Diagram_LinkUID
        
        l_cHtml += [</span>]
        //---------------------------------------------------------------------------
    
    l_cHtml += [</div>]
l_cHtml += [</nav>]


l_nLengthDecoded := hb_jsonDecode(l_cNodePositions,@l_hNodePositions)
if l_nLengthDecoded > 0
    //migrate from x,y coordinates that may be negative
    // if GRAPH_LIB_DD == "mxgraph"
    if l_nRenderMode == RENDERMODE_MXGRAPH
        for each l_hNodePosition in l_hNodePositions
            l_cHashKey := l_hNodePosition:__enumkey
            if left(l_cHashKey, 1) == "T"
                if l_hNodePosition["x"] < l_nMinX
                    l_nMinX = l_hNodePosition["x"]
                endif
                if l_hNodePosition["y"] < l_nMinY
                    l_nMinY = l_hNodePosition["y"]
                endif
            endif
        endfor
        for each l_hNodePosition in l_hNodePositions
            l_cHashKey := l_hNodePosition:__enumkey
            if left(l_cHashKey, 1) == "T"
                l_hNodePosition["x"] += (-l_nMinX)
                l_hNodePosition["y"] += (-l_nMinY)
            endif
        endfor
    endif
endif

l_cHtml += [<table><tr>]
l_cHtml += [<div id="buttons" class="mb-2"></div>]
l_cHtml += [</tr>]
l_cHtml += [<tr>]
//-------------------------------------
l_cHtml += [<td valign="top">]
l_cHtml += [<div id="mynetwork" style="overflow:scroll"></div>]
l_cHtml += [</td>]
//-------------------------------------

if empty(l_cDiagramInfoScale)
    l_nDiagramInfoScale := 1
else
    l_nDiagramInfoScale := val(l_cDiagramInfoScale)
    if l_nDiagramInfoScale < 0.4 .or. l_nDiagramInfoScale > 1.0
        l_nDiagramInfoScale := 1
    endif
endif


l_cHtml += [<td valign="top">]  // width="100%"
if l_nDiagramInfoScale == 1
    l_cHtml += [<div id="GraphInfo"></div>]
else
    l_cHtml += [<div id="GraphInfo" style="transform: scale(]+alltrim(str(l_nDiagramInfoScale,10,2))+[);transform-origin: 0 0;"></div>]
endif
l_cHtml += [</td>]
//-------------------------------------
l_cHtml += [</tr></table>]

//Code used to debug the positions.
// l_cHtml += [<div><input type="text" name="TextNodePositions" id="TextNodePositions" size="100" value=""></div>]

l_cHtml += [</form>]

// Example for altering the Navigation controls.
// l_cHtml += [<style>]
// l_cHtml += [ .vis-button {background-color:#FF0000;} ]
// l_cHtml += [</style>]

l_cHtml += [<script type="text/javascript">]

l_cHtml += [var network;]

l_cHtml += [function MakeVis(){]

// create an array with nodes
l_cHtml += 'var nodes = ['
select ListOfTables
scan all
    if l_lShowNamespace
        l_cNodeLabel := AllTrim(ListOfTables->Namespace_Name)+"."
    else
        l_cNodeLabel := ""
    endif

    do case
    case l_nNodeDisplayMode == 1 //Table Name and Alias
        l_cNodeLabel += AllTrim(ListOfTables->Table_Name)
        if ListOfTables->Table_Unlogged
            l_cNodeLabel += [\n<small><mark>UNLOGGED</mark></small>]
        endif
        if !hb_orm_isnull("ListOfTables","Table_AKA")
            l_cNodeLabel += [</b>\n(]+ListOfTables->Table_AKA+[)]  // no &nbsp; supported
        else
            l_cNodeLabel += [</b>]
        endif
    case l_nNodeDisplayMode == 2 //Table Alias or Name
        if ListOfTables->Table_Unlogged
            if !hb_orm_isnull("ListOfTables","Table_AKA")
                l_cNodeLabel += AllTrim(ListOfTables->Table_AKA)+[\n<small><mark>UNLOGGED</mark></small></b>]
            else
                l_cNodeLabel += AllTrim(ListOfTables->Table_Name)+[\n<small><mark>UNLOGGED</mark></small></b>]
            endif
        else
            if !hb_orm_isnull("ListOfTables","Table_AKA")
                l_cNodeLabel += AllTrim(ListOfTables->Table_AKA)+[</b>]
            else
                l_cNodeLabel += AllTrim(ListOfTables->Table_Name)+[</b>]
            endif
        endif
    case l_nNodeDisplayMode == 3 //Table Name
        if ListOfTables->Table_Unlogged
            l_cNodeLabel += AllTrim(ListOfTables->Table_Name)+[\n<small><mark>UNLOGGED</mark></small></b>]
        else
            l_cNodeLabel += AllTrim(ListOfTables->Table_Name)+[</b>]
        endif
    endcase
    l_cNodeLabel := [<b>]+l_cNodeLabel

    // if hb_orm_isnull("ListOfTables","Table_Description")
    //     l_cTableDescription := ""
    // else
    //     l_cTableDescription := hb_StrReplace(ListOfTables->Table_Description,{[&]     => [&#38;],;
    //                                                                           [\]     => [&#92;],;
    //                                                                           chr(10) => [],;
    //                                                                           chr(13) => [\n],;
    //                                                                           ["]     => [&#34;],;
    //                                                                           [']     => [&#39;]} )
    // endif
    l_cTableDescription := EscapeNewlineAndQuotes(ListOfTables->Table_Description)

    //Due to some bugs in the js library, had to setup font before the label.
    l_cHtml += [{id:"T]+Trans(ListOfTables->pk)+["]
    l_cHtml += [,font:{multi:"html",align:"left"}]
    if empty(l_cTableDescription)
        l_cHtml += [,label:"]+l_cNodeLabel+["]
    else
        if l_lNodeShowDescription
            l_cHtml += [,label:"]+l_cNodeLabel+[\n]+l_cTableDescription+["]
        else
            if l_lNeverShowDescriptionOnHover
                l_cHtml += [,label:"]+l_cNodeLabel+["]
            else
                l_cHtml += [,label:"]+l_cNodeLabel+[",title:"]+l_cTableDescription+["]
            endif
        endif
    endif

    // 1 Unknown
    // 2 Proposed
    // 3 Under Development
    // 4 Active
    // 5 To Be Discontinued
    // 6 Discontinued

    do case
    case ListOfTables->Table_UseStatus <= USESTATUS_UNKNOWN
        if l_lUnknownInGray
            l_cHtml += [,color:{background:'#]+USESTATUS_1_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_1_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]
        else
            l_cHtml += [,color:{background:'#]+USESTATUS_4_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_4_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]
        endif

    case ListOfTables->Table_UseStatus == USESTATUS_PROPOSED
        l_cHtml += [,color:{background:'#]+USESTATUS_2_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_2_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]

    case ListOfTables->Table_UseStatus == USESTATUS_UNDERDEVELOPMENT
        l_cHtml += [,color:{background:'#]+USESTATUS_3_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_3_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]

    case ListOfTables->Table_UseStatus == USESTATUS_ACTIVE
        l_cHtml += [,color:{background:'#]+USESTATUS_4_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_4_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]

    case ListOfTables->Table_UseStatus == USESTATUS_TOBEDISCONTINUED
        l_cHtml += [,color:{background:'#]+USESTATUS_5_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_5_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]

    case ListOfTables->Table_UseStatus >= USESTATUS_DISCONTINUED
        l_cHtml += [,color:{background:'#]+USESTATUS_6_NODE_BACKGROUND+[',highlight:{background:'#]+USESTATUS_6_NODE_HIGHLIGHT+[',border:'#]+SELECTED_NODE_BORDER+['}}]

    endcase

    if l_nNodeMaxWidth > 50
        l_cHtml += [,widthConstraint: {maximum: ]+Trans(l_nNodeMaxWidth)+[}]
    endif
    if l_nNodeMinHeight > 20
        l_cHtml += [,heightConstraint: {minimum: ]+Trans(l_nNodeMinHeight)+[}]
    endif

    if l_nLengthDecoded > 0
        l_hCoordinate := hb_HGetDef(l_hNodePositions,"T"+Trans(ListOfTables->pk),{=>})
        if len(l_hCoordinate) > 0
            l_lAutoLayout := .f.
            l_cHtml += [,x:]+Trans(l_hCoordinate["x"])+[,y:]+Trans(l_hCoordinate["y"])
            if hb_HHasKey(l_hCoordinate, "height")
                l_cHtml += [,height:]+Trans(l_hCoordinate["height"])
            endif
            if hb_HHasKey(l_hCoordinate, "width")
                l_cHtml += [,width:]+Trans(l_hCoordinate["width"])
            endif
        endif
    endif

    if oFcgi:p_nAccessLevelDD < 4
        l_cHtml += [,fixed: {x:true,y:true}]
    endif

    l_cHtml += [},]
endscan
l_cHtml += '];'

//Pre-Determine multi-links
select ListOfLinks
scan all
    l_cMultiEdgeKey := Trans(ListOfLinks->pkFrom)+"-"+Trans(ListOfLinks->pkTo)
    l_hMultiEdgeCounters[l_cMultiEdgeKey] := hb_HGetDef(l_hMultiEdgeCounters,l_cMultiEdgeKey,0) + 1
endscan

l_cHtml += 'var edges = ['

l_cMultiEdgeKeyPrevious := ""

select ListOfLinks
scan all

    //1="NotSet", 2="Protect", 3="Cascade", 4="BreakLink"
    //Arrow options:  classic,classicThin, block,blockThin,open,openThin, oval, diamond, diamondThin

    if ListOfLinks->Column_ForeignKeyOptional
        l_cArrowType := "open"
    else
        l_cArrowType := "block"
    endif
    if ListOfLinks->Column_OnDelete != 2  // Not a Protected Relationship
        l_cArrowType += "Thin"
    endif

    l_cHtml += [{id:"C]+Trans(ListOfLinks->Column_Pk)+[",from:"T]+Trans(ListOfLinks->pkFrom)+[",to:"T]+Trans(ListOfLinks->pkTo)+[",arrows:{from:{enabled: true,type:"]+l_cArrowType+["}}]

    do case
    case ListOfLinks->Column_UseStatus <= USESTATUS_UNKNOWN
        if l_lUnknownInGray
            l_cHtml += [,color:{color:'#]+USESTATUS_1_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_1_EDGE_HIGHLIGHT+['}]
        else
            l_cHtml += [,color:{color:'#]+USESTATUS_4_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_4_EDGE_HIGHLIGHT+['}]
        endif
    case ListOfLinks->Column_UseStatus == USESTATUS_PROPOSED
        l_cHtml += [,color:{color:'#]+USESTATUS_2_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_2_EDGE_HIGHLIGHT+['}]
    case ListOfLinks->Column_UseStatus == USESTATUS_UNDERDEVELOPMENT
        l_cHtml += [,color:{color:'#]+USESTATUS_3_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_3_EDGE_HIGHLIGHT+['}]
    case ListOfLinks->Column_UseStatus == USESTATUS_ACTIVE
        l_cHtml += [,color:{color:'#]+USESTATUS_4_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_4_EDGE_HIGHLIGHT+['}]
    case ListOfLinks->Column_UseStatus == USESTATUS_TOBEDISCONTINUED
        l_cHtml += [,color:{color:'#]+USESTATUS_5_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_5_EDGE_HIGHLIGHT+['}]
    case ListOfLinks->Column_UseStatus >= USESTATUS_DISCONTINUED
        l_cHtml += [,color:{color:'#]+USESTATUS_6_EDGE_BACKGROUND+[',highlight:'#]+USESTATUS_6_EDGE_HIGHLIGHT+['}]
    endcase

    if !empty(nvl(ListOfLinks->Column_ForeignKeyUse,""))
        l_cHtml += [,label:"]+EscapeNewlineAndQuotes(ListOfLinks->Column_ForeignKeyUse)+["]
    endif

    l_cMultiEdgeKey := Trans(ListOfLinks->pkFrom)+"-"+Trans(ListOfLinks->pkTo)
    l_nMultiEdgeTotalCount := l_hMultiEdgeCounters[l_cMultiEdgeKey]
    if l_nMultiEdgeTotalCount > 1
        if l_cMultiEdgeKey == l_cMultiEdgeKeyPrevious
            l_nMultiEdgeCount += 1
        else
            l_nMultiEdgeCount := 1
            l_cMultiEdgeKeyPrevious := l_cMultiEdgeKey
        endif
        l_cHtml += GetMultiEdgeCurvatureJSon(l_nMultiEdgeTotalCount,l_nMultiEdgeCount)
    endif

    if l_nLengthDecoded > 0
        l_hCoordinate := hb_HGetDef(l_hNodePositions,"C"+Trans(ListOfLinks->Column_Pk),{=>})
        if len(l_hCoordinate) > 0
            l_lAutoLayout := .f.
            l_cHtml += [,points:]+hb_jsonEncode(l_hCoordinate["points"])
        endif
    endif

// l_cHtml += [,labelFrom:"CS"]
// l_cHtml += [,arrowWidth:60]

    

    l_cHtml += [},]  //,physics: false , smooth: { type: "cubicBezier" }
endscan

l_cHtml += '];'

// create a network
l_cHtml += [  var container = document.getElementById("mynetwork");]

// if GRAPH_LIB_DD == "mxgraph"
if l_nRenderMode == RENDERMODE_MXGRAPH

// See visualization.js .. function createGraph(container, nodes, edges, autoLayout, rerouteEdgesOnVertexMove, edgeLayout, resetEdges) {
    l_cHtml += [ network = createGraph(container, nodes, edges, ]+iif(l_lAutoLayout,"true","false")+[, false, "orthogonal", ] + iif(l_nMinX > 0 .or. l_nMinY > 0,"true","false") + [); ]
    l_cHtml += ' network.getSelectionModel().addListener(mxEvent.CHANGE, function (sender, evt) {'
    l_cHtml += '     var cellsAdded = evt.getProperty("removed");'
    l_cHtml += '     var cellAdded = (cellsAdded && cellsAdded.length >0) ? cellsAdded[0] : null;'
    l_cHtml += '     var cellsRemoved = evt.getProperty("added");'
    l_cHtml += '     var cellRemoved = (cellsRemoved && cellsRemoved.length >0) ? cellsRemoved[0] : null;'
    l_cHtml += '     SelectGraphCell(cellsAdded,cellsRemoved,network);'
    l_cHtml += '     var params = {};'
    l_cHtml += '     if (cellAdded != null) {'
    l_cHtml += '         if(cellAdded.id.startsWith("T")) {'
    l_cHtml += '             params.nodes = [ cellAdded.id ];'
    l_cHtml += '         }'
    l_cHtml += '         else if(cellAdded.id.startsWith("C")) {'
    l_cHtml += '             params.edges = [ cellAdded.id ];'
    l_cHtml += '             params.items = [ { edgeId : cellAdded.id } ];'
    l_cHtml += '         }'
    l_cHtml += '     }'
    l_cHtml += '     evt.consume();'

    l_cHtml += '     network.setAllowDanglingEdges(false);'
    l_cHtml += '     network.setDisconnectOnMove(false);'

// elseif GRAPH_LIB_DD == "visjs"
else
    l_cHtml += [  var data = {]
    l_cHtml += [    nodes: new vis.DataSet(nodes),]
    l_cHtml += [    edges: new vis.DataSet(edges),]
    l_cHtml += [  };]
    l_cHtml += [  var options = {nodes:{shape:"box",margin:12,physics:false,labelHighlightBold:false},]

    l_cHtml +=                  [edges:{physics:false},]   // ,selectionWidth: 2
    if l_lNavigationControl
        l_cHtml +=              [interaction:{navigationButtons:true},]
    endif
    l_cHtml +=                  [};]

    l_cHtml += [  network = new vis.Network(container, data, options);]  //var
    l_cHtml += ' network.on("click", function (params) {'
    l_cHtml += '   params.event = "[original event]";'
endif

// Code to filter columns
l_cJS := [$("#ColumnSearch").change(function() {]
l_cJS +=    [var l_keywords =  $(this).val();]
l_cJS +=    [$(".SpanColumnName").each(function (par_SpanTable){]+;
                                                           [var l_cColumnName = $(this).text();]+;
                                                           [if (KeywordSearch(l_keywords,l_cColumnName)) {$(this).parent().parent().parent().show();} else {$(this).parent().parent().parent().hide();}]+;
                                                           [});]
l_cJS += [});]

// Code to prevent the enter key from submitting the form but still trigger the .change()
l_cJS += [$("#ColumnSearch").keydown(function(e) {]
l_cJS +=    [var key = e.charCode ? e.charCode : e.keyCode ? e.keyCode : 0;]
l_cJS +=    [if(e.keyCode == 13 && e.target.type !== 'submit') {]
l_cJS +=      [e.preventDefault();]
l_cJS +=      [return $(e.target).blur().focus();]
l_cJS +=    [}]
l_cJS += [});]

// Code to enable the "All" and "Core Only" button. JavaScript code executed after the right panel is loaded.
l_cJS += [$("#ButtonShowAll").click(function(){$("#ColumnSearch").val("");$(".ColumnNotCore").show(),$(".ColumnCore").show();});]
l_cJS += [$("#ButtonShowCoreOnly").click(function(){$("#ColumnSearch").val("");$(".ColumnNotCore").hide(),$(".ColumnCore").show();});]
l_cJS += [$('.DisplayEnum').tooltip({html: true,sanitize: false});]

l_cHtml += '   $("#GraphInfo" ).load( "'+l_cSitePath+'ajax/GetDDInfo","diagrampk='+Trans(l_iDiagramPk)+'&info="+JSON.stringify(params) , function(){'+l_cJS+'});'
l_cHtml += '      });'

// if GRAPH_LIB_DD == "mxgraph"
if l_nRenderMode == RENDERMODE_MXGRAPH
    l_cHtml += ' network.model.addListener(mxEvent.CHANGE, function (sender, evt) {'
    l_cHtml += '    var changes = evt.getProperty("edit").changes;'
    l_cHtml += '    for (var i = 0; i < changes.length; i++) { '
    l_cHtml += '        if(changes[i].constructor.name ==  "mxGeometryChange") {'
    l_cHtml += '           $("#ButtonSaveLayout").addClass("btn-warning").removeClass("btn-primary");'
    l_cHtml += '        }'
    l_cHtml += '    }'
    l_cHtml += ' });'
// elseif GRAPH_LIB_DD == "visjs"
else
    l_cHtml += ' network.on("dragStart", function (params) {'
    l_cHtml += '   params.event = "[original event]";'
    // l_cHtml += '   debugger;'
    l_cHtml += "   if (params['nodes'].length == 1) {$('#ButtonSaveLayout').addClass('btn-warning').removeClass('btn-primary');};"
    l_cHtml += '      });'
    l_cHtml += [network.fit();]
endif

l_cHtml += [};]

l_cHtml += [</script>]

oFcgi:p_cjQueryScript += [MakeVis();]

// oFcgi:p_cjQueryScript += [$(document).on("keydown", "form", function(event) { return event.key != "Enter";});] // To prevent enter key from submitting form

return l_cHtml
//=================================================================================================================
function DataDictionaryVisualizeDiagramOnSubmit(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
local l_cHtml := []

local l_cActionOnSubmit := oFcgi:GetInputValue("ActionOnSubmit")
local l_oDB_Diagram := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_cNodePositions
local l_oDB1
local l_oDB2
local l_oDB3
local l_iDiagramPk
local l_cListOfRelatedTablePks
local l_aListOfRelatedTablePks
local l_nNumberOfCurrentTablesInDiagram
local l_lSelected
local l_cTablePk
local l_iTablePk
local l_oDataDiagram
local l_nRenderMode

oFcgi:TraceAdd("DataDictionaryVisualizeDiagramOnSubmit")

l_iDiagramPk := Val(oFcgi:GetInputValue("TextDiagramPk"))

do case
case l_cActionOnSubmit == "Show"
    l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

case l_cActionOnSubmit == "DiagramSettings" .and. oFcgi:p_nAccessLevelDD >= 4
    l_cHtml := DataDictionaryVisualizeDiagramSettingsBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

case l_cActionOnSubmit == "MyDiagramSettings"
    l_cHtml := DataDictionaryVisualizeMyDiagramSettingsBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

case l_cActionOnSubmit == "NewDiagram" .and. oFcgi:p_nAccessLevelDD >= 4
    l_cHtml := DataDictionaryVisualizeDiagramSettingsBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,0)

case l_cActionOnSubmit == "DuplicateDiagram" .and. oFcgi:p_nAccessLevelDD >= 4
    l_cHtml := DataDictionaryVisualizeDiagramDuplicateBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

case ("SaveLayout" $ l_cActionOnSubmit) .and. oFcgi:p_nAccessLevelDD >= 4
    l_cNodePositions  := Strtran(SanitizeInput(oFcgi:GetInputValue("TextNodePositions")),[%22],["])
    l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)

    if empty(l_iDiagramPk)
        l_nRenderMode := RENDERMODE_MXGRAPH
    else
        with object l_oDB_Diagram
            :Table("edbccb15-007b-4de6-8281-5cfaf5f452cf","Diagram")
            :Column("Diagram.RenderMode"         ,"Diagram_RenderMode")
            l_oDataDiagram := :Get(l_iDiagramPk)
            l_nRenderMode := max(RENDERMODE_VISJS,l_oDataDiagram:Diagram_RenderMode)
        endwith
    endif

    with object l_oDB1
        :Table("617ce583-369e-468b-9227-63bb429564a0","Diagram")
        if l_nRenderMode == RENDERMODE_MXGRAPH
            :Field("Diagram.MxgPos",l_cNodePositions)
        else
            :Field("Diagram.VisPos",l_cNodePositions)
        endif
        if empty(l_iDiagramPk)
            //Add an initial Diagram File this should not happen, since record was already added
            :Field("Diagram.fk_Application",par_iApplicationPk)
            :Field("Diagram.Name"          ,"All Tables")
            :Field("Diagram.UseStatus"     ,USESTATUS_UNKNOWN)
            :Field("Diagram.DocStatus"     ,DOCTATUS_MISSING)
            :Field("Diagram.RenderMode"    ,RENDERMODE_MXGRAPH)
            :Field("Diagram.LinkUID"       ,oFcgi:p_o_SQLConnection:GetUUIDString())
            if :Add()
                l_iDiagramPk := :Key()
            endif
        else
            :Update(l_iDiagramPk)
        endif
    endwith

    if "UpdateTableSelection" $ l_cActionOnSubmit
        l_cListOfRelatedTablePks := SanitizeInput(oFcgi:GetInputValue("TextListOfRelatedTablePks"))
        l_aListOfRelatedTablePks := hb_ATokens(l_cListOfRelatedTablePks,"*")
        if len(l_aListOfRelatedTablePks) > 0
            // Get the current list of tables

            with Object l_oDB1
                :Table("a702abbf-4c4e-44f7-a1fe-aefb3f99ff8b","DiagramTable")
                :Distinct(.t.)
                :Column("Table.pk","pk")
                :Column("DiagramTable.pk","DiagramTable_pk")
                :Join("inner","Table","","DiagramTable.fk_Table = Table.pk")
                :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
                :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
                :SQL("ListOfCurrentTablesInDiagram")
                l_nNumberOfCurrentTablesInDiagram := :Tally
                if l_nNumberOfCurrentTablesInDiagram > 0
                    with object :p_oCursor
                        :Index("pk","pk")
                        :CreateIndexes()
                        :SetOrder("pk")
                    endwith        
                endif
            endwith
            if l_nNumberOfCurrentTablesInDiagram < 0
                //Failed to get current list of tables in the diagram
            else
                if empty(l_nNumberOfCurrentTablesInDiagram)
                    //Implicitly all tables are in the diagram. So should formally add all of them except the unselected ones.
                    l_oDB2 := hb_SQLData(oFcgi:p_o_SQLConnection)
                    l_oDB3 := hb_SQLData(oFcgi:p_o_SQLConnection)
                    with object l_oDB2
                        :Table("24d7118f-c867-4f8e-ab1c-e1404766081b","Diagram")
                        :Column("Table.pk" , "Table_pk")
                        :Where("Diagram.pk = ^" , l_iDiagramPk)
                        :Join("Inner","Namespace","","Namespace.fk_Application = Diagram.fk_Application")
                        :Join("Inner","Table","","Table.fk_Namespace = Namespace.pk")
                        :SQL("ListOfAllApplicationTable")
                        if :Tally > 0
                            select ListOfAllApplicationTable
                            scan all
                                if "*"+Trans(ListOfAllApplicationTable->Table_pk)+"*" $ "*" +l_cListOfRelatedTablePks+ "*"  //One of the related tables
                                    // "CheckTable"
                                    l_lSelected := (oFcgi:GetInputValue("CheckTable"+Trans(ListOfAllApplicationTable->Table_pk)) == "1")
                                else
                                    l_lSelected := .t.
                                endif
                                if l_lSelected
                                    with object l_oDB3
                                        :Table("adee80f0-932a-40c2-92bd-91c4daad0ce7","DiagramTable")
                                        :Field("DiagramTable.fk_Diagram" , l_iDiagramPk)
                                        :Field("DiagramTable.fk_Table"   , ListOfAllApplicationTable->Table_pk)
                                        :Add()
                                    endwith
                                endif
                            endscan
                        endif
                    endwith

                else
                    //Add or remove only the related tables that were listed.
                    l_oDB3 := hb_SQLData(oFcgi:p_o_SQLConnection)
                    for each l_cTablePk in l_aListOfRelatedTablePks
                        l_lSelected := (oFcgi:GetInputValue("CheckTable"+l_cTablePk) == "1")

                        if l_lSelected
                            if !VFP_Seek(val(l_cTablePk),"ListOfCurrentTablesInDiagram","pk")
                                //Add if not present
                                with object l_oDB3
                                    :Table("d653adf7-19bf-4c6a-b2d5-8c9043ce7061","DiagramTable")
                                    :Field("DiagramTable.fk_Diagram" , l_iDiagramPk)
                                    :Field("DiagramTable.fk_Table"   , val(l_cTablePk))
                                    :Add()
                                endwith
                            endif
                        else
                            if VFP_Seek(val(l_cTablePk),"ListOfCurrentTablesInDiagram","pk")
                                //Remove if present
                                l_oDB3:Delete("3ac82b2c-63eb-4604-8bf4-0271e17a5c6c","DiagramTable",ListOfCurrentTablesInDiagram->DiagramTable_pk)
                            endif
                        endif

                    endfor
                endif
            endif

        endif
    endif

    if "RemoveTable" $ l_cActionOnSubmit
        l_iTablePk := val(oFcgi:GetInputValue("TextTablePkToRemove"))
        if l_iTablePk > 0
            // Get the current list of tables

            with Object l_oDB1
                :Table("1195f023-29b5-4fe9-9070-21eb078a8f90","DiagramTable")
                :Distinct(.t.)
                :Column("Table.pk","pk")
                :Column("DiagramTable.pk","DiagramTable_pk")
                :Join("inner","Table","","DiagramTable.fk_Table = Table.pk")
                :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
                :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
                :SQL("ListOfCurrentTablesInDiagram")
                l_nNumberOfCurrentTablesInDiagram := :Tally
                if l_nNumberOfCurrentTablesInDiagram > 0
                    with object :p_oCursor
                        :Index("pk","pk")
                        :CreateIndexes()
                        :SetOrder("pk")
                    endwith        
                endif
            endwith
            if l_nNumberOfCurrentTablesInDiagram < 0
                //Failed to get current list of tables in the diagram
            else
                if empty(l_nNumberOfCurrentTablesInDiagram)
                    //Implicitly all tables are in the diagram. So should formally add all of them except the the current one.
                    l_oDB2 := hb_SQLData(oFcgi:p_o_SQLConnection)
                    l_oDB3 := hb_SQLData(oFcgi:p_o_SQLConnection)
                    with object l_oDB2
                        :Table("e9e09007-67ad-4029-8187-050396590662","Diagram")
                        :Column("Table.pk" , "Table_pk")
                        :Where("Diagram.pk = ^" , l_iDiagramPk)
                        :Join("Inner","Namespace","","Namespace.fk_Application = Diagram.fk_Application")
                        :Join("Inner","Table","","Table.fk_Namespace = Namespace.pk")
                        :SQL("ListOfAllApplicationTable")
                        if :Tally > 0
                            select ListOfAllApplicationTable
                            scan all
                                if ListOfAllApplicationTable->Table_pk <> l_iTablePk
                                    with object l_oDB3
                                        :Table("4b80fd71-4d3f-4ae1-84bc-509391db42b7","DiagramTable")
                                        :Field("DiagramTable.fk_Diagram" , l_iDiagramPk)
                                        :Field("DiagramTable.fk_Table"   , ListOfAllApplicationTable->Table_pk)
                                        :Add()
                                    endwith
                                endif
                            endscan
                        endif
                    endwith

                else
                    //Remove only the current tables.
                    l_oDB3 := hb_SQLData(oFcgi:p_o_SQLConnection)
                    if VFP_Seek(l_iTablePk,"ListOfCurrentTablesInDiagram","pk")
                        //Remove if still present
                        l_oDB3:Delete("a66d5243-995d-421e-9687-fb7fe1be895b","DiagramTable",ListOfCurrentTablesInDiagram->DiagramTable_pk)
                    endif
                endif
            endif

        endif
    endif

    l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

endcase

return l_cHtml
//=================================================================================================================
//=================================================================================================================
function DataDictionaryVisualizeDiagramSettingsBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,par_iDiagramPk,par_hValues)

local l_cHtml := ""
local l_cErrorText   := hb_DefaultValue(par_cErrorText,"")
local l_hValues      := hb_DefaultValue(par_hValues,{=>})
local l_CheckBoxId
local l_lShowNamespace
local l_cNamespace_Name
local l_nNodeDisplayMode
local l_nRenderMode
local l_lNodeShowDescription
local l_nNodeMinHeight
local l_nNodeMaxWidth

local l_oDB1
local l_oData

oFcgi:TraceAdd("DataDictionaryVisualizeDiagramSettingsBuild")

l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)

if pcount() < 6
    if par_iDiagramPk > 0
        // Initial Build, meaning not from a failing editing
        with object l_oDB1
            //Get current Diagram Name
            :Table("cadc1049-56e3-4efa-bb61-dd9396e2c6fe","Diagram")
            :Column("Diagram.name"               ,"Diagram_name")
            :Column("Diagram.NodeDisplayMode"    ,"Diagram_NodeDisplayMode")
            :Column("Diagram.RenderMode"         ,"Diagram_RenderMode")
            :Column("Diagram.VisPos"             ,"Diagram_VisPos")
            :Column("Diagram.NodeShowDescription","Diagram_NodeShowDescription")
            :Column("Diagram.NodeMinHeight"      ,"Diagram_NodeMinHeight")
            :Column("Diagram.NodeMaxWidth"       ,"Diagram_NodeMaxWidth")
            l_oData := :Get(par_iDiagramPk)
            if :Tally == 1
                l_hValues["Name"]                := l_oData:Diagram_name
                l_hValues["NodeDisplayMode"]     := l_oData:Diagram_NodeDisplayMode
                l_hValues["RenderMode"]          := l_oData:Diagram_RenderMode
                l_hValues["NodeShowDescription"] := l_oData:Diagram_NodeShowDescription
                l_hValues["NodeMinHeight"]       := l_oData:Diagram_NodeMinHeight
                l_hValues["NodeMaxWidth"]        := l_oData:Diagram_NodeMaxWidth
            endif

            //Get the current list of selected tables
            :Table("1f5273de-4ed2-49e3-a82e-580b842025d9","DiagramTable")
            :Distinct(.t.)
            :Column("Table.pk","pk")
            :Join("inner","Table","","DiagramTable.fk_Table = Table.pk")        //Extra Join to filter out possible orphan records
            :Where("DiagramTable.fk_Diagram = ^" , par_iDiagramPk)
            :SQL("ListOfCurrentTablesInDiagram")            
            if :Tally > 0
                select ListOfCurrentTablesInDiagram
                scan all
                    l_hValues["Table"+Trans(ListOfCurrentTablesInDiagram->pk)] := .t.
                endscan
            endif
        endwith
    endif
endif

l_cHtml += [<form action="" method="post" name="form" enctype="multipart/form-data">]
l_cHtml += [<input type="hidden" name="formname" value="DiagramSettings">]
l_cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]
l_cHtml += [<input type="hidden" id="TextDiagramPk" name="TextDiagramPk" value="]+trans(par_iDiagramPk)+[">]

if !empty(par_cErrorText)
    l_cHtml += [<div class="p-3 mb-2 bg-danger text-white">]+par_cErrorText+[</div>]
endif

l_cHtml += [<nav class="navbar navbar-light bg-light">]
    l_cHtml += [<div class="input-group">]
        l_cHtml += [<span class="navbar-brand ms-3">]+iif(empty(par_iDiagramPk),"New Diagram","Diagram Settings")+[</span>]   //navbar-text
        l_cHtml += [<input type="button" class="btn btn-primary rounded ms-0" id="ButtonSave" value="Save" onclick="$('#ActionOnSubmit').val('SaveDiagram');document.form.submit();" role="button">]
        l_cHtml += [<input type="button" class="btn btn-primary rounded ms-3" value="Cancel" onclick="$('#ActionOnSubmit').val('Cancel');document.form.submit();" role="button">]
        if !empty(par_iDiagramPk)
            l_cHtml += [<button type="button" class="btn btn-danger rounded ms-5" data-bs-toggle="modal" data-bs-target="#ConfirmDeleteModal">Delete</button>]
            l_cHtml += [<input type="button" class="btn btn-primary rounded ms-5" value="Reset" onclick="$('#ActionOnSubmit').val('ResetLayout');document.form.submit();" role="button">]
        endif
    l_cHtml += [</div>]
l_cHtml += [</nav>]

l_cHtml += [<div class="m-3"></div>]

l_cHtml += [<div class="m-3">]

    l_cHtml += [<table>]

        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">Diagram Name</td>]
            l_cHtml += [<td class="pb-3"><input]+UPDATESAVEBUTTON+[ type="text" name="TextName" id="TextName" value="]+FcgiPrepFieldForValue(hb_HGetDef(l_hValues,"Name",""))+[" maxlength="200" size="80"></td>]
        l_cHtml += [</tr>]

        l_nNodeDisplayMode := hb_HGetDef(l_hValues,"NodeDisplayMode",1)
        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">Node Display</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<select]+UPDATESAVEBUTTON+[ name="ComboNodeDisplayMode" id="ComboNodeDisplayMode">]
                    l_cHtml += [<option value="1"]+iif(l_nNodeDisplayMode==1,[ selected],[])+[>Table Name and Alias</option>]
                    l_cHtml += [<option value="2"]+iif(l_nNodeDisplayMode==2,[ selected],[])+[>Table Alias or Name</option>]
                    l_cHtml += [<option value="3"]+iif(l_nNodeDisplayMode==3,[ selected],[])+[>Table Name</option>]
                l_cHtml += [</select>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]

        l_nRenderMode := hb_HGetDef(l_hValues,"RenderMode",RENDERMODE_MXGRAPH)
        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">Render Mode</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<select]+UPDATESAVEBUTTON+[ name="ComboRenderMode" id="ComboRenderMode">]
                    l_cHtml += [<option value="1"]+iif(l_nRenderMode==1,[ selected],[])+[>Straight Connectors (visjs)</option>]
                    l_cHtml += [<option value="2"]+iif(l_nRenderMode==2,[ selected],[])+[>Custom Connectors (mxgraph)</option>]
                l_cHtml += [</select>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]

        l_lNodeShowDescription := hb_HGetDef(l_hValues,"NodeShowDescription",.f.)
        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">Node Table Description</td>]
            l_cHtml += [<td class="pb-3"><div class="form-check form-switch">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="CheckNodeShowDescription" id="CheckNodeShowDescription" value="1"]+iif(l_lNodeShowDescription," checked","")+[ class="form-check-input">]
            l_cHtml += [</div></td>]
        l_cHtml += [</tr>]

        l_nNodeMinHeight := hb_HGetDef(l_hValues,"NodeMinHeight",50)
        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">Node Minimum Height</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="input" name="TextNodeMinHeight" id="TextNodeMinHeight" value="]+iif(empty(l_nNodeMinHeight),"",Trans(l_nNodeMinHeight))+[" size="4" maxlength="4">]
                l_cHtml += [<span>&nbsp;(In Pixels)&nbsp;(Optional)</span>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]

        l_nNodeMaxWidth := hb_HGetDef(l_hValues,"NodeMaxWidth",150)
        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">Node Maximum Width</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="input" name="TextNodeMaxWidth" id="TextNodeMaxWidth" value="]+iif(empty(l_nNodeMaxWidth),"",Trans(l_nNodeMaxWidth))+[" size="4" maxlength="4">]
                l_cHtml += [<span>&nbsp;(In Pixels)&nbsp;(Optional)</span>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]

    l_cHtml += [</table>]
    
l_cHtml += [</div>]

l_cHtml += [<div class="m-3"></div>]
//List all the tables

l_lShowNamespace := .f.

with Object l_oDB1
    :Table("ce7c29dc-9396-4fbb-9704-eb121bf139a2","Table")
    :Column("Table.pk"         ,"pk")
    :Column("Namespace.Name"   ,"Namespace_Name")
    :Column("Table.Name"       ,"Table_Name")
    :Column("Table.AKA"        ,"Table_AKA")
    :Column("Table.UseStatus"  ,"Table_UseStatus")
    :Column("Table.DocStatus"  ,"Table_DocStatus")
    :Column("Table.Description","Table_Description")
    :Column("Upper(Namespace.Name)","tag1")
    :Column("Upper(Table.Name)","tag2")
    :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
    :Where("Namespace.fk_Application = ^",par_iApplicationPk)
    :OrderBy("tag1")
    :OrderBy("tag2")
    :SQL("ListOfAllTablesInApplication")
//SendToDebugView(:GetLastEventId(),:LastSQL())
    if :Tally > 0
        
        l_cHtml += [<div class="ms-3"><span>Filter on Table Name</span><input type="text" id="TableSearch" value="" size="40" class="ms-2"><span class="ms-3"> (Press Enter)</span></div>]

        l_cHtml += [<div class="m-3"></div>]

        if :Tally > 1  //Will only display Namespace names if there are more than 1 name space used
            select ListOfAllTablesInApplication
            l_cNamespace_Name := ListOfAllTablesInApplication->Namespace_Name  //Get name from first record
            locate for ListOfAllTablesInApplication->Namespace_Name <> l_cNamespace_Name
            l_lShowNamespace := Found()
        endif
    endif
endwith

// //Add a case insensitive contains(), icontains()
// oFcgi:p_cjQueryScript += "jQuery.expr[':'].icontains = function(a, i, m) {"
// oFcgi:p_cjQueryScript += "  return jQuery(a).text().toUpperCase()"
// oFcgi:p_cjQueryScript += "      .indexOf(m[3].toUpperCase()) >= 0;"
// oFcgi:p_cjQueryScript += "};"

// oFcgi:p_cjQueryScript += [$("#TableSearch").change(function() {]
// oFcgi:p_cjQueryScript += [$(".SPANTable:icontains('" + $(this).val() + "')").parent().parent().show();]
// oFcgi:p_cjQueryScript += [$(".SPANTable:not(:icontains('" + $(this).val() + "'))").parent().parent().hide();]
// oFcgi:p_cjQueryScript += [});]

oFcgi:p_cjQueryScript += 'function KeywordSearch(par_cListOfWords, par_cString) {'
oFcgi:p_cjQueryScript += '  const l_aWords_upper = par_cListOfWords.toUpperCase().split(" ").filter(Boolean);'
oFcgi:p_cjQueryScript += '  const l_cString_upper = par_cString.toUpperCase();'
oFcgi:p_cjQueryScript += '  var l_lAllWordsIncluded = true;'
oFcgi:p_cjQueryScript += '  for (var i = 0; i < l_aWords_upper.length; i++) {'
oFcgi:p_cjQueryScript += '    if (!l_cString_upper.includes(l_aWords_upper[i])) {l_lAllWordsIncluded = false;break;};'
oFcgi:p_cjQueryScript += '  }'
oFcgi:p_cjQueryScript += '  return l_lAllWordsIncluded;'
oFcgi:p_cjQueryScript += '}'

oFcgi:p_cjQueryScript += [$("#TableSearch").change(function() {]
oFcgi:p_cjQueryScript +=    [var l_keywords =  $(this).val();]
oFcgi:p_cjQueryScript +=    [$(".SPANTable").each(function (par_SpanTable){]+;
                                                                           [var l_cTableName = $(this).text();]+;
                                                                           [if (KeywordSearch(l_keywords,l_cTableName)) {$(this).parent().parent().show();} else {$(this).parent().parent().hide();}]+;
                                                                           [});]
oFcgi:p_cjQueryScript += [});]

l_cHtml += [<div class="form-check form-switch">]
l_cHtml += [<table class="ms-5">]
select ListOfAllTablesInApplication
scan all
    l_CheckBoxId := "CheckTable"+Trans(ListOfAllTablesInApplication->pk)
    l_cHtml += [<tr><td>]
        l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="]+l_CheckBoxId+[" id="]+l_CheckBoxId+[" value="1"]+iif( hb_HGetDef(l_hValues,"Table"+Trans(ListOfAllTablesInApplication->pk),.f.)," checked","")+[ class="form-check-input">]
        l_cHtml += [<label class="form-check-label" for="]+l_CheckBoxId+["><span class="SPANTable">]+iif(l_lShowNamespace,ListOfAllTablesInApplication->Namespace_Name+[.],[])+ListOfAllTablesInApplication->Table_Name+FormatAKAForDisplay(ListOfAllTablesInApplication->Table_AKA)
        l_cHtml += [</span></label>]
    l_cHtml += [</td></tr>]
endscan
l_cHtml += [</table>]
l_cHtml += [</div>]

oFcgi:p_cjQueryScript += [$('#TextName').focus();]

l_cHtml += [</form>]

l_cHtml += GetConfirmationModalFormsDelete()

return l_cHtml
//=================================================================================================================
function DataDictionaryVisualizeDiagramSettingsOnSubmit(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
local l_cHtml := []

local l_cActionOnSubmit := oFcgi:GetInputValue("ActionOnSubmit")
local l_cNodePositions
local l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB2 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB3 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_iDiagramPk
local l_cDiagram_Name
local l_nDiagram_NodeDisplayMode
local l_nDiagram_RenderMode
local l_lDiagram_NodeShowDescription
local l_lDiagram_NodeMinHeight
local l_lDiagram_NodeMaxWidth
local l_cErrorMessage
local l_lSelected
local l_hValues := {=>}
local l_oDataDiagram
local l_nRenderMode
local l_nRenderMode_OnFile
local l_cVisPos_OnFile
local l_cMxgPos_OnFile

oFcgi:TraceAdd("DataDictionaryVisualizeDiagramSettingsOnSubmit")

l_iDiagramPk                   := Val(oFcgi:GetInputValue("TextDiagramPk"))
l_cDiagram_Name                := SanitizeInput(oFcgi:GetInputValue("TextName"))
l_nDiagram_NodeDisplayMode     := val(oFcgi:GetInputValue("ComboNodeDisplayMode"))
l_nDiagram_RenderMode          := val(oFcgi:GetInputValue("ComboRenderMode"))
l_lDiagram_NodeShowDescription := (oFcgi:GetInputValue("CheckNodeShowDescription") == "1")
l_lDiagram_NodeMinHeight       := min(9999,max(0,Val(SanitizeInput(oFcgi:GetInputValue("TextNodeMinHeight")))))
l_lDiagram_NodeMaxWidth        := min(9999,max(0,Val(SanitizeInput(oFcgi:GetInputValue("TextNodeMaxWidth")))))

do case
case l_cActionOnSubmit == "SaveDiagram"
    //Get all the Application Tables to help scan all the selection checkboxes.
    with Object l_oDB2
        :Table("70126bd9-f5b7-49e1-8d65-6aef01ab3368","Table")
        :Column("Table.pk"         ,"pk")
        :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
        :Where("Namespace.fk_Application = ^",par_iApplicationPk)
        :SQL("ListOfAllTablesInApplication")
    endwith

    do case
    case empty(l_cDiagram_Name)
        l_cErrorMessage := "Missing Name"
    otherwise
        with object l_oDB1
            :Table("bcc7cf4c-4fb4-41a3-a8d8-88c8c9f3d797","Diagram")
            :Where([lower(replace(Diagram.Name,' ','')) = ^],lower(StrTran(l_cDiagram_Name," ","")))
            :Where([Diagram.fk_Application = ^],par_iApplicationPk)
            if l_iDiagramPk > 0
                :Where([Diagram.pk != ^],l_iDiagramPk)
            endif
            :SQL()
        endwith
        if l_oDB1:Tally <> 0
            l_cErrorMessage := "Duplicate Name"
        endif
    endcase

    if empty(l_cErrorMessage)
        with object l_oDB1
            // Find preview value of RenderMode to determine if should Initialize MxgPos to VisPos
            if !empty(l_iDiagramPk)
                :Table("393c9962-a6ca-486a-bd7c-f8409d069cfd","Diagram")
                :Column("Diagram.RenderMode"         ,"Diagram_RenderMode")
                :Column("Diagram.VisPos"             ,"Diagram_VisPos")
                :Column("Diagram.MxgPos"             ,"Diagram_MxgPos")
                l_oDataDiagram := :Get(l_iDiagramPk)
                if :Tally == 1
                    l_nRenderMode_OnFile := l_oDataDiagram:Diagram_RenderMode
                    l_cVisPos_OnFile     := l_oDataDiagram:Diagram_VisPos
                    l_cMxgPos_OnFile     := l_oDataDiagram:Diagram_MxgPos
                else
                    l_nRenderMode_OnFile := 0
                endif
            endif


            :Table("d303eed8-944e-4a7c-8314-133eb13fca3d","Diagram")
            :Field("Diagram.Name"               ,l_cDiagram_Name)
            :Field("Diagram.NodeDisplayMode"    ,l_nDiagram_NodeDisplayMode)
            :Field("Diagram.RenderMode"         ,l_nDiagram_RenderMode)
            if l_nRenderMode_OnFile == RENDERMODE_VISJS .and. l_nDiagram_RenderMode == RENDERMODE_MXGRAPH .and. hb_IsNIL(l_cMxgPos_OnFile) .and. !hb_IsNIL(l_cVisPos_OnFile)
                //If switching from visjs to mxgraph rendering mode with no MxgPos value and existing VisPos value
                :Field("Diagram.MxgPos",l_cVisPos_OnFile)
            endif
            :Field("Diagram.NodeShowDescription",l_lDiagram_NodeShowDescription)
            :Field("Diagram.NodeMinHeight"      ,l_lDiagram_NodeMinHeight)
            :Field("Diagram.NodeMaxWidth"       ,l_lDiagram_NodeMaxWidth)
            if empty(l_iDiagramPk)  // Should not happen
                :Field("Diagram.fk_Application",par_iApplicationPk)
                :Field("Diagram.UseStatus"     ,USESTATUS_UNKNOWN)
                :Field("Diagram.DocStatus"     ,DOCTATUS_MISSING)
                :Field("Diagram.LinkUID"       ,oFcgi:p_o_SQLConnection:GetUUIDString())
                if :Add()
                    l_iDiagramPk := :Key()
                else
                    l_iDiagramPk := 0
                    l_cErrorMessage := "Failed to save changes!"
                endif
            else
                if !:Update(l_iDiagramPk)
                    l_cErrorMessage := "Failed to save changes!"
                endif

            endif
        endwith
    endif

    if empty(l_cErrorMessage)
        //Update the list selected tables
        //Get current list of diagram tables
        with Object l_oDB1
            :Table("225a41d2-6c7d-4c3d-bdbb-4757f6acc087","DiagramTable")
            :Distinct(.t.)
            :Column("Table.pk","pk")
            :Column("DiagramTable.pk","DiagramTable_pk")
            :Join("inner","Table","","DiagramTable.fk_Table = Table.pk")
            :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
            :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
            :SQL("ListOfCurrentTablesInDiagram")
            with object :p_oCursor
                :Index("pk","pk")
                :CreateIndexes()
                :SetOrder("pk")
            endwith        
        endwith

        select ListOfAllTablesInApplication
        scan all
            l_lSelected := (oFcgi:GetInputValue("CheckTable"+Trans(ListOfAllTablesInApplication->pk)) == "1")

            if VFP_Seek(ListOfAllTablesInApplication->pk,"ListOfCurrentTablesInDiagram","pk")
                if !l_lSelected
                    // Remove the table
                    with Object l_oDB3
                        if !:Delete("254d6227-f160-412e-a8b7-9ff4f3cf1dc5","DiagramTable",ListOfCurrentTablesInDiagram->DiagramTable_pk)
                            l_cErrorMessage := "Failed to Save table selection."
                            exit
                        endif
                    endwith
                endif
            else
                if l_lSelected
                    // Add the table
                    with Object l_oDB3
                        :Table("0f252d7a-6656-4ef0-a2be-f85bf84f93fb","DiagramTable")
                        :Field("DiagramTable.fk_Table"   ,ListOfAllTablesInApplication->pk)
                        :Field("DiagramTable.fk_Diagram" ,l_iDiagramPk)
                        if !:Add()
                            l_cErrorMessage := "Failed to Save table selection."
                            exit
                        endif
                    endwith
                endif
            endif
        endscan
    else
        // Keep current list of selection to be used by Build
    endif

    if empty(l_cErrorMessage)
        l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)
    else
        l_hValues["Name"]                := l_cDiagram_Name
        l_hValues["NodeDisplayMode"]     := l_nDiagram_NodeDisplayMode
        l_hValues["RenderMode"]          := l_nDiagram_RenderMode
        l_hValues["NodeShowDescription"] := l_lDiagram_NodeShowDescription
        l_hValues["NodeMinHeight"]       := l_lDiagram_NodeMinHeight
        l_hValues["NodeMaxWidth"]        := l_lDiagram_NodeMaxWidth
        
        select ListOfAllTablesInApplication
        scan all
            l_lSelected := (oFcgi:GetInputValue("CheckTable"+Trans(ListOfAllTablesInApplication->pk)) == "1")
            if l_lSelected  // No need to store the unselect references, since not having a reference will mean "not selected"
                l_hValues["Table"+Trans(ListOfAllTablesInApplication->pk)] := .t.
            endif
        endscan
        l_cHtml := DataDictionaryVisualizeDiagramSettingsBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk,l_hValues)
    endif

case l_cActionOnSubmit == "Cancel"
    l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

case l_cActionOnSubmit == "Delete"
    with object l_oDB1
        //Delete related records in DiagramTable
        :Table("c4d616b9-9f17-47f2-a536-42ec624b3d46","DiagramTable")
        :Column("DiagramTable.pk","pk")
        :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
        :SQL("ListOfDiagramTableToDelete")
        select ListOfDiagramTableToDelete
        scan all
            :Delete("469afb28-2829-4400-9670-a3e6acfd592a","DiagramTable",ListOfDiagramTableToDelete->pk)
        endscan
        
        //Delete related records in UserSetting
        :Table("c4d616b9-9f17-47f2-a536-42ec624b3d47","UserSetting")
        :Column("UserSetting.pk","pk")
        :Where("UserSetting.fk_Diagram = ^" , l_iDiagramPk)
        :SQL("ListOfUserSettingToDelete")
        select ListOfUserSettingToDelete
        scan all
            :Delete("469afb28-2829-4400-9670-a3e6acfd592b","UserSetting",ListOfUserSettingToDelete->pk)
        endscan
        
        :Delete("a9a53831-eceb-4280-ba8d-23decf60c87c","Diagram",l_iDiagramPk)
    endwith
    oFcgi:Redirect(oFcgi:p_cSitePath+"DataDictionaries/Visualize/"+par_cURLApplicationLinkCode+"/")

case l_cActionOnSubmit == "ResetLayout"
    if !empty(l_iDiagramPk)
        with object l_oDB1
            :Table("bdb0a61a-0bb1-48b0-8d6a-5e29e96414f2","Diagram")
            :Column("Diagram.RenderMode"         ,"Diagram_RenderMode")
            l_oDataDiagram := :Get(l_iDiagramPk)
            l_nRenderMode := max(RENDERMODE_VISJS,l_oDataDiagram:Diagram_RenderMode)

            :Table("222b379f-8605-40ce-a35f-c57fecd78d08","Diagram")
            if l_nRenderMode == RENDERMODE_MXGRAPH
                :Field("Diagram.MxgPos",NIL)
            else
                :Field("Diagram.VisPos",NIL)
            endif
            :Update(l_iDiagramPk)
        endwith
    endif

    l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

endcase

return l_cHtml
//=================================================================================================================
function DataDictionaryVisualizeDiagramDuplicateBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,par_iDiagramPk,par_hValues)

local l_cHtml := ""
local l_cErrorText   := hb_DefaultValue(par_cErrorText,"")
local l_hValues      := hb_DefaultValue(par_hValues,{=>})

local l_oDB1
local l_oData

oFcgi:TraceAdd("DataDictionaryVisualizeDiagramDuplicateBuild")

l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)

if pcount() < 6
    if par_iDiagramPk > 0
        with object l_oDB1
            //Get current Diagram Name
            :Table("e833b9f1-4427-4001-965d-f02f3d071b87","Diagram")
            :Column("Diagram.name" ,"Diagram_name")
            l_oData := :Get(par_iDiagramPk)
            if :Tally == 1
                l_hValues["Name"] := l_oData:Diagram_name
            endif
        endwith
    endif
endif

l_cHtml += [<form action="" method="post" name="form" enctype="multipart/form-data">]
l_cHtml += [<input type="hidden" name="formname" value="DuplicateDiagram">]
l_cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]
l_cHtml += [<input type="hidden" id="TextDiagramPk" name="TextDiagramPk" value="]+trans(par_iDiagramPk)+[">]

if !empty(par_cErrorText)
    l_cHtml += [<div class="p-3 mb-2 bg-danger text-white">]+par_cErrorText+[</div>]
endif

l_cHtml += [<nav class="navbar navbar-light bg-light">]
    l_cHtml += [<div class="input-group">]
        l_cHtml += [<span class="navbar-brand ms-3">Duplicate Diagram</span>]   //navbar-text
        l_cHtml += [<input type="button" class="btn btn-primary rounded ms-0" id="ButtonSave" value="Save" onclick="$('#ActionOnSubmit').val('DuplicateDiagram');document.form.submit();" role="button">]
        l_cHtml += [<input type="button" class="btn btn-primary rounded ms-3" value="Cancel" onclick="$('#ActionOnSubmit').val('Cancel');document.form.submit();" role="button">]
    l_cHtml += [</div>]
l_cHtml += [</nav>]

l_cHtml += [<div class="m-3"></div>]

l_cHtml += [<div class="m-3">]

    l_cHtml += [<table>]

        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">New Diagram Name</td>]
            l_cHtml += [<td class="pb-3"><input]+UPDATESAVEBUTTON+[ type="text" name="TextName" id="TextName" value="]+FcgiPrepFieldForValue(hb_HGetDef(l_hValues,"Name",""))+[" maxlength="200" size="80"></td>]
        l_cHtml += [</tr>]

    l_cHtml += [</table>]
    
l_cHtml += [</div>]

oFcgi:p_cjQueryScript += [$('#TextName').focus();]

l_cHtml += [</form>]

l_cHtml += GetConfirmationModalFormsDelete()

return l_cHtml
//=================================================================================================================
function DataDictionaryVisualizeDiagramDuplicateOnSubmit(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
local l_cHtml := []

local l_cActionOnSubmit := oFcgi:GetInputValue("ActionOnSubmit")
local l_cNodePositions
local l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB2 := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_iDiagramPk
local l_iNewDiagramPk
local l_cDiagram_Name
local l_cErrorMessage
local l_hValues := {=>}
local l_oDataDiagram

oFcgi:TraceAdd("DataDictionaryVisualizeDiagramDuplicateOnSubmit")

l_iDiagramPk    := Val(oFcgi:GetInputValue("TextDiagramPk"))
l_cDiagram_Name := SanitizeInput(oFcgi:GetInputValue("TextName"))

do case
case l_cActionOnSubmit == "DuplicateDiagram"

    do case
    case empty(l_iDiagramPk)
        l_cErrorMessage := "Missing Diagram Pk"
    case empty(l_cDiagram_Name)
        l_cErrorMessage := "Missing Name"
    otherwise
        with object l_oDB1
            // Avoid duplicating name
            :Table("8af8349e-adf2-427a-ad6d-918b984d3e07","Diagram")
            :Where([lower(replace(Diagram.Name,' ','')) = ^],lower(StrTran(l_cDiagram_Name," ","")))
            :Where([Diagram.fk_Application = ^],par_iApplicationPk)
            :SQL()
        endwith
        if l_oDB1:Tally <> 0
            l_cErrorMessage := "Duplicate Name"
        endif
    endcase

    if empty(l_cErrorMessage)
        with object l_oDB1
            //Get the source Diagram Column Values
            :Table("6c6404f1-b321-459c-9a2b-df2329325091","Diagram")
            :Column("Diagram.UseStatus"           ,"Diagram_UseStatus")
            :Column("Diagram.DocStatus"           ,"Diagram_DocStatus")
            :Column("Diagram.Description"         ,"Diagram_Description")
            :Column("Diagram.NodeDisplayMode"     ,"Diagram_NodeDisplayMode")
            :Column("Diagram.NodeShowDescription" ,"Diagram_NodeShowDescription")
            :Column("Diagram.NodeDisplayMode"     ,"Diagram_NodeDisplayMode")
            :Column("Diagram.RenderMode"          ,"Diagram_RenderMode")
            :Column("Diagram.VisPos"              ,"Diagram_VisPos")
            :Column("Diagram.MxgPos"              ,"Diagram_MxgPos")
            // :Column("Diagram.LinkUID"             ,"Diagram_LinkUID")
            :Column("Diagram.NodeMaxWidth"        ,"Diagram_NodeMaxWidth")
            :Column("Diagram.NodeMinHeight"       ,"Diagram_NodeMinHeight")
            l_oDataDiagram := :Get(l_iDiagramPk)
            if :Tally == 1

                :Table("5f129adf-af33-4b70-9c1f-3b1a10921b2a","Diagram")
                :Field("Diagram.fk_Application"      ,par_iApplicationPk)
                :Field("Diagram.LinkUID"             ,oFcgi:p_o_SQLConnection:GetUUIDString())
                :Field("Diagram.Name"                ,l_cDiagram_Name)
                :Field("Diagram.UseStatus"           ,l_oDataDiagram:Diagram_UseStatus)
                :Field("Diagram.DocStatus"           ,l_oDataDiagram:Diagram_DocStatus)
                :Field("Diagram.Description"         ,l_oDataDiagram:Diagram_Description)
                :Field("Diagram.NodeDisplayMode"     ,l_oDataDiagram:Diagram_NodeDisplayMode)
                :Field("Diagram.NodeShowDescription" ,l_oDataDiagram:Diagram_NodeShowDescription)
                :Field("Diagram.NodeDisplayMode"     ,l_oDataDiagram:Diagram_NodeDisplayMode)
                :Field("Diagram.RenderMode"          ,l_oDataDiagram:Diagram_RenderMode)
                :Field("Diagram.VisPos"              ,l_oDataDiagram:Diagram_VisPos)
                :Field("Diagram.MxgPos"              ,l_oDataDiagram:Diagram_MxgPos)
                :Field("Diagram.NodeMaxWidth"        ,l_oDataDiagram:Diagram_NodeMaxWidth)
                :Field("Diagram.NodeMinHeight"       ,l_oDataDiagram:Diagram_NodeMinHeight)

                if :Add()
                    l_iNewDiagramPk := :Key()

                    // Duplicate the DiagramTable records
                    :Table("91cf88f8-992e-4852-8a10-376feec30950","DiagramTable")
                    :Column("DiagramTable.fk_Table" , "DiagramTable_fk_Table")
                    :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
                    :SQL("ListOfSourceDiagramTables")

                    if :Tally > 1
                        select ListOfSourceDiagramTables
                        scan all
                            with object l_oDB2
                                :Table("ba188227-4e99-4219-bf13-53186a4ed638","DiagramTable")
                                :Field("DiagramTable.fk_Diagram" , l_iNewDiagramPk)
                                :Field("DiagramTable.fk_Table"   , ListOfSourceDiagramTables->DiagramTable_fk_Table)
                                :Add()
                            endwith
                        endscan
                    endif
                else
                    l_cErrorMessage := "Failed to save changes!"
                endif

            else
                l_cErrorMessage := "Failed to load Source information."
            endif
        endwith
    endif

    if empty(l_cErrorMessage)
        l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iNewDiagramPk)  // l_iDiagramPk
    else
        l_hValues["Name"] := l_cDiagram_Name
        
        l_cHtml := DataDictionaryVisualizeDiagramDuplicateBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk,l_hValues)
    endif

case l_cActionOnSubmit == "Cancel"
    l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

endcase

return l_cHtml
//=================================================================================================================
//=================================================================================================================
// The Following function was used by deprecated Ajax Call
// function SaveVisualizationPositions()

// local l_iApplicationPk := val(oFcgi:GetQueryString("apppk"))
// local l_cNodePositions := Strtran(oFcgi:GetQueryString("pos"),[%22],["])

// local l_oDB1 := hb_SQLData(oFcgi:p_o_SQLConnection)

// with object l_oDB1
//     :Table("44111d36-963b-42f1-b4e5-4c4e4e5ffd13","Application")
//     :Field("Application.VisPos",l_cNodePositions)
//     :Update(l_iApplicationPk)
// endwith

// return ""
//=================================================================================================================
//=================================================================================================================
function DataDictionaryVisualizeMyDiagramSettingsBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,par_iDiagramPk,par_hValues)
local l_cHtml := ""
local l_cErrorText   := hb_DefaultValue(par_cErrorText,"")
local l_hValues      := hb_DefaultValue(par_hValues,{=>})
local l_cDiagramInfoScale
local l_nDiagramInfoScale

local l_lPreviousThisDiagramOnly := (GetUserSetting("ThisDiagramOnly",par_iDiagramPk) == "T")
local l_lThisDiagramOnly
local l_nSize
local l_iCanvasWidth
local l_iCanvasHeight
local l_lNavigationControl
local l_lUnknownInGray
local l_lNeverShowDescriptionOnHover

oFcgi:TraceAdd("DataDictionaryVisualizeMyDiagramSettingsBuild")

if pcount() < 6
    if par_iDiagramPk > 0
        l_lThisDiagramOnly := (GetUserSetting("ThisDiagramOnly",par_iDiagramPk) == "T")
        l_hValues["ThisDiagramOnly"]  := l_lThisDiagramOnly


        if l_lThisDiagramOnly
            l_cDiagramInfoScale := GetUserSetting("DiagramInfoScale",par_iDiagramPk)
            if empty(l_cDiagramInfoScale)
                l_cDiagramInfoScale := GetUserSetting("DiagramInfoScale")
            endif
        else
            l_cDiagramInfoScale := GetUserSetting("DiagramInfoScale")
        endif
        if empty(l_cDiagramInfoScale)
            l_nDiagramInfoScale := 1
        else
            l_nDiagramInfoScale := val(l_cDiagramInfoScale)
            if l_nDiagramInfoScale < 0.4 .or. l_nDiagramInfoScale > 1.0
                l_nDiagramInfoScale := 1
            endif
        endif
        l_hValues["DiagramInfoScale"]  := l_nDiagramInfoScale   // 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4


        if l_lThisDiagramOnly
            l_iCanvasWidth  := val(GetUserSetting("CanvasWidth",par_iDiagramPk))
            if empty(l_cDiagramInfoScale)
                l_iCanvasWidth  := val(GetUserSetting("CanvasWidth"))
            endif
        else
            l_iCanvasWidth  := val(GetUserSetting("CanvasWidth"))
        endif
        if l_iCanvasWidth < CANVAS_WIDTH_MIN .or. l_iCanvasWidth > CANVAS_WIDTH_MAX
            l_iCanvasWidth := CANVAS_WIDTH_DEFAULT
        endif
        l_hValues["CanvasWidth"]  := l_iCanvasWidth


        if l_lThisDiagramOnly
            l_iCanvasHeight := val(GetUserSetting("CanvasHeight",par_iDiagramPk))
            if empty(l_cDiagramInfoScale)
                l_iCanvasHeight := val(GetUserSetting("CanvasHeight"))
            endif
        else
            l_iCanvasHeight := val(GetUserSetting("CanvasHeight"))
        endif
        if l_iCanvasHeight < CANVAS_HEIGHT_MIN .or. l_iCanvasHeight > CANVAS_HEIGHT_MAX
            l_iCanvasHeight := CANVAS_HEIGHT_DEFAULT
        endif
        l_hValues["CanvasHeight"]  := l_iCanvasHeight


        if l_lThisDiagramOnly
            l_lNavigationControl := (GetUserSetting("NavigationControl",par_iDiagramPk) == "T")
            if empty(l_cDiagramInfoScale)
                l_lNavigationControl := (GetUserSetting("NavigationControl") == "T")
            endif
        else
            l_lNavigationControl := (GetUserSetting("NavigationControl") == "T")
        endif
        l_hValues["NavigationControl"]  := l_lNavigationControl


        if l_lThisDiagramOnly
            l_lUnknownInGray := (GetUserSetting("UnknownInGray",par_iDiagramPk) == "T")
            if empty(l_cDiagramInfoScale)
                l_lUnknownInGray := (GetUserSetting("UnknownInGray") == "T")
            endif
        else
            l_lUnknownInGray := (GetUserSetting("UnknownInGray") == "T")
        endif
        l_hValues["UnknownInGray"]  := l_lUnknownInGray


        if l_lThisDiagramOnly
            l_lNeverShowDescriptionOnHover := (GetUserSetting("NeverShowDescriptionOnHover",par_iDiagramPk) == "T")
            if empty(l_cDiagramInfoScale)
                l_lNeverShowDescriptionOnHover := (GetUserSetting("NeverShowDescriptionOnHover") == "T")
            endif
        else
            l_lNeverShowDescriptionOnHover := (GetUserSetting("NeverShowDescriptionOnHover") == "T")
        endif
        l_hValues["NeverShowDescriptionOnHover"]  := l_lNeverShowDescriptionOnHover

    endif
endif

l_cHtml += [<form action="" method="post" name="form" enctype="multipart/form-data">]
l_cHtml += [<input type="hidden" name="formname" value="MyDiagramSettings">]
l_cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]
l_cHtml += [<input type="hidden" id="TextDiagramPk" name="TextDiagramPk" value="]+trans(par_iDiagramPk)+[">]

if !empty(par_cErrorText)
    l_cHtml += [<div class="p-3 mb-2 bg-danger text-white">]+par_cErrorText+[</div>]
endif

l_cHtml += [<nav class="navbar navbar-light bg-light">]
    l_cHtml += [<div class="input-group">]
        l_cHtml += [<span class="navbar-brand ms-3">My Settings</span>]   //navbar-text
        l_cHtml += [<input type="button" class="btn btn-primary rounded ms-0" id="ButtonSave" value="Save" onclick="$('#ActionOnSubmit').val('SaveMySettings');document.form.submit();" role="button">]
        l_cHtml += [<input type="button" class="btn btn-primary rounded ms-3" value="Cancel" onclick="$('#ActionOnSubmit').val('Cancel');document.form.submit();" role="button">]
    l_cHtml += [</div>]
l_cHtml += [</nav>]

l_cHtml += [<div class="m-3"></div>]

l_cHtml += [<div class="m-3">]

    l_cHtml += [<table>]

        l_lThisDiagramOnly := hb_HGetDef(l_hValues,"ThisDiagramOnly",.f.)
        l_cHtml += [<tr class="pb-5">]
            l_cHtml += [<td class="pe-2 pb-3">For Current Diagram Only</td>]
            l_cHtml += [<td class="pb-3"><div class="form-check form-switch">]
                l_cHtml += [<input type="hidden" id="CheckPreviousThisDiagramOnly" name="CheckPreviousThisDiagramOnly" value="]+iif(l_lPreviousThisDiagramOnly,"1","0")+[">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="CheckThisDiagramOnly" id="CheckThisDiagramOnly" value="1"]+iif(l_lThisDiagramOnly," checked","")+[ class="form-check-input"]
                if l_lThisDiagramOnly  //If turning off the setting, hide all the other settings.
                    l_cHtml += [ onclick='$(".DiagramSettings").toggleClass("d-none",!$("#CheckThisDiagramOnly").is(":checked"));']
                endif
                l_cHtml += [>]
            l_cHtml += [</div></td>]
        l_cHtml += [</tr>]


        l_nDiagramInfoScale := hb_HGetDef(l_hValues,"DiagramInfoScale",1)
        l_cHtml += [<tr class="pb-5 DiagramSettings">]
            l_cHtml += [<td class="pe-2 pb-3">Right Panel Scale</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<select]+UPDATESAVEBUTTON+[ name="ComboDiagramInfoScale" id="ComboDiagramInfoScale">]
                    l_cHtml += [<option value="1"]  +iif(l_nDiagramInfoScale==1  ,[ selected],[])+[>1.0</option>]
                    l_cHtml += [<option value="0.9"]+iif(l_nDiagramInfoScale==0.9,[ selected],[])+[>0.9</option>]
                    l_cHtml += [<option value="0.8"]+iif(l_nDiagramInfoScale==0.8,[ selected],[])+[>0.8</option>]
                    l_cHtml += [<option value="0.7"]+iif(l_nDiagramInfoScale==0.7,[ selected],[])+[>0.7</option>]
                    l_cHtml += [<option value="0.6"]+iif(l_nDiagramInfoScale==0.6,[ selected],[])+[>0.6</option>]
                    l_cHtml += [<option value="0.5"]+iif(l_nDiagramInfoScale==0.5,[ selected],[])+[>0.5</option>]
                    l_cHtml += [<option value="0.4"]+iif(l_nDiagramInfoScale==0.4,[ selected],[])+[>0.4</option>]
                l_cHtml += [</select>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]


        l_iCanvasWidth := hb_HGetDef(l_hValues,"CanvasWidth",CANVAS_WIDTH_DEFAULT)
        if l_iCanvasWidth < CANVAS_WIDTH_MIN .or. l_iCanvasWidth > CANVAS_WIDTH_MAX
            l_iCanvasWidth := CANVAS_WIDTH_DEFAULT
        endif
        l_cHtml += [<tr class="pb-5 DiagramSettings">]
            l_cHtml += [<td class="pe-2 pb-3">Canvas Width</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<select]+UPDATESAVEBUTTON+[ name="ComboCanvasWidth" id="ComboCanvasWidth">]
                    for l_nSize := CANVAS_WIDTH_MIN to CANVAS_WIDTH_MAX step 100
                        l_cHtml += [<option value="]+Trans(l_nSize)+["]+iif(l_iCanvasWidth==l_nSize,[ selected],[])+[>]+Trans(l_nSize)+[</option>]
                    endfor
                l_cHtml += [</select>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]


        l_iCanvasHeight := hb_HGetDef(l_hValues,"CanvasHeight",CANVAS_HEIGHT_DEFAULT)
        if l_iCanvasHeight < CANVAS_HEIGHT_MIN .or. l_iCanvasHeight > CANVAS_HEIGHT_MAX
            l_iCanvasHeight := CANVAS_HEIGHT_DEFAULT
        endif
        l_cHtml += [<tr class="pb-5 DiagramSettings">]
            l_cHtml += [<td class="pe-2 pb-3">Canvas Height</td>]
            l_cHtml += [<td class="pb-3">]
                l_cHtml += [<select]+UPDATESAVEBUTTON+[ name="ComboCanvasHeight" id="ComboCanvasHeight">]
                    for l_nSize := CANVAS_HEIGHT_MIN to CANVAS_HEIGHT_MAX step 100
                        l_cHtml += [<option value="]+Trans(l_nSize)+["]+iif(l_iCanvasHeight==l_nSize,[ selected],[])+[>]+Trans(l_nSize)+[</option>]
                    endfor
                l_cHtml += [</select>]
            l_cHtml += [</td>]
        l_cHtml += [</tr>]


        l_lNavigationControl := hb_HGetDef(l_hValues,"NavigationControl",.f.)
        l_cHtml += [<tr class="pb-5 DiagramSettings">]
            l_cHtml += [<td class="pe-2 pb-3">Display Navigation Controls</td>]
            l_cHtml += [<td class="pb-3"><div class="form-check form-switch">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="CheckNavigationControl" id="CheckNavigationControl" value="1"]+iif(l_lNavigationControl," checked","")+[ class="form-check-input">]
            l_cHtml += [</div></td>]
        l_cHtml += [</tr>]


        l_lUnknownInGray := hb_HGetDef(l_hValues,"UnknownInGray",.f.)
        l_cHtml += [<tr class="pb-5 DiagramSettings">]
            l_cHtml += [<td class="pe-2 pb-3">Unknown Usage Status in Gray</td>]
            l_cHtml += [<td class="pb-3"><div class="form-check form-switch">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="CheckUnknownInGray" id="CheckUnknownInGray" value="1"]+iif(l_lUnknownInGray," checked","")+[ class="form-check-input">]
            l_cHtml += [</div></td>]
        l_cHtml += [</tr>]


        l_lNeverShowDescriptionOnHover := hb_HGetDef(l_hValues,"NeverShowDescriptionOnHover",.f.)
        l_cHtml += [<tr class="pb-5 DiagramSettings">]
            l_cHtml += [<td class="pe-2 pb-3">Never Show Description On Hover</td>]
            l_cHtml += [<td class="pb-3"><div class="form-check form-switch">]
                l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="CheckNeverShowDescriptionOnHover" id="CheckNeverShowDescriptionOnHover" value="1"]+iif(l_lNeverShowDescriptionOnHover," checked","")+[ class="form-check-input">]
            l_cHtml += [</div></td>]
        l_cHtml += [</tr>]


    l_cHtml += [</table>]
    
l_cHtml += [</div>]

l_cHtml += [<div class="m-3"></div>]

oFcgi:p_cjQueryScript += [$('#ComboDiagramInfoScale').focus();]

l_cHtml += [</form>]

l_cHtml += GetConfirmationModalFormsDelete()

return l_cHtml
//=================================================================================================================
function DataDictionaryVisualizeMyDiagramSettingsOnSubmit(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode)
local l_cHtml := []

local l_cActionOnSubmit := oFcgi:GetInputValue("ActionOnSubmit")
local l_iDiagramPk

local l_lPreviousThisDiagramOnly
local l_lThisDiagramOnly
local l_cDiagramInfoScale
local l_nDiagramInfoScale
local l_iCanvasWidth
local l_iCanvasHeight
local l_lNavigationControl
local l_lUnknownInGray
local l_lNeverShowDescriptionOnHover

local l_cErrorMessage := ""
local l_lSelected
local l_hValues := {=>}

oFcgi:TraceAdd("DataDictionaryVisualizeMyDiagramSettingsOnSubmit")

l_iDiagramPk               := Val(oFcgi:GetInputValue("TextDiagramPk"))
l_lPreviousThisDiagramOnly := (oFcgi:GetInputValue("CheckPreviousThisDiagramOnly") == "1")
l_lThisDiagramOnly         := (oFcgi:GetInputValue("CheckThisDiagramOnly") == "1")

do case
case l_cActionOnSubmit == "SaveMySettings"
    SaveUserSetting("ThisDiagramOnly",iif(l_lThisDiagramOnly,"T","F"),l_iDiagramPk)

    if l_lPreviousThisDiagramOnly .and. !l_lThisDiagramOnly
        // Turning off "For Current Diagram Only" setting, so will not apply the settings globally.
        // Go back and allow to edit global settings by fetching again the current non current diagram specific settings.

        l_cDiagramInfoScale := GetUserSetting("DiagramInfoScale")
        if empty(l_cDiagramInfoScale)
            l_nDiagramInfoScale := 1
        else
            l_nDiagramInfoScale := val(l_cDiagramInfoScale)
            if l_nDiagramInfoScale < 0.4 .or. l_nDiagramInfoScale > 1.0
                l_nDiagramInfoScale := 1
            endif
        endif

        l_iCanvasWidth  := val(GetUserSetting("CanvasWidth"))
        if l_iCanvasWidth < CANVAS_WIDTH_MIN .or. l_iCanvasWidth > CANVAS_WIDTH_MAX
            l_iCanvasWidth := CANVAS_WIDTH_DEFAULT
        endif

        l_iCanvasHeight := val(GetUserSetting("CanvasHeight"))
        if l_iCanvasHeight < CANVAS_HEIGHT_MIN .or. l_iCanvasHeight > CANVAS_HEIGHT_MAX
            l_iCanvasHeight := CANVAS_HEIGHT_DEFAULT
        endif

        l_hValues["ThisDiagramOnly"]              := l_lThisDiagramOnly   //.f.
        l_hValues["DiagramInfoScale"]             := l_nDiagramInfoScale
        l_hValues["CanvasWidth"]                  := l_iCanvasWidth
        l_hValues["CanvasHeight"]                 := l_iCanvasHeight
        l_hValues["NavigationControl"]            := (GetUserSetting("NavigationControl") == "T")
        l_hValues["UnknownInGray"]                := (GetUserSetting("UnknownInGray") == "T")
        l_hValues["NeverShowDescriptionOnHover"]  := (GetUserSetting("NeverShowDescriptionOnHover") == "T")

        l_cHtml := DataDictionaryVisualizeMyDiagramSettingsBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk,l_hValues)

    else
        l_nDiagramInfoScale            := val(oFcgi:GetInputValue("ComboDiagramInfoScale"))
        l_iCanvasWidth                 := val(oFcgi:GetInputValue("ComboCanvasWidth"))
        l_iCanvasHeight                := val(oFcgi:GetInputValue("ComboCanvasHeight"))
        l_lNavigationControl           := (oFcgi:GetInputValue("CheckNavigationControl") == "1")
        l_lUnknownInGray               := (oFcgi:GetInputValue("CheckUnknownInGray") == "1")
        l_lNeverShowDescriptionOnHover := (oFcgi:GetInputValue("CheckNeverShowDescriptionOnHover") == "1")

        if l_nDiagramInfoScale < 0.4 .or. l_nDiagramInfoScale > 1.0
            l_nDiagramInfoScale := 1
        endif

        if l_iCanvasWidth < CANVAS_WIDTH_MIN .or. l_iCanvasWidth > CANVAS_WIDTH_MAX
            l_iCanvasWidth := CANVAS_WIDTH_DEFAULT
        endif

        if l_iCanvasHeight < CANVAS_HEIGHT_MIN .or. l_iCanvasHeight > CANVAS_HEIGHT_MAX
            l_iCanvasHeight := CANVAS_HEIGHT_DEFAULT
        endif

        //May not simply store blanks on default values, since we have a 2 tiers approach (Diagram Specific, than any Diagrams)
        SaveUserSetting("DiagramInfoScale"           ,alltrim(str(l_nDiagramInfoScale,10,2))     ,iif(l_lThisDiagramOnly,l_iDiagramPk,0))
        SaveUserSetting("CanvasWidth"                ,Trans(l_iCanvasWidth)                      ,iif(l_lThisDiagramOnly,l_iDiagramPk,0))
        SaveUserSetting("CanvasHeight"               ,Trans(l_iCanvasHeight)                     ,iif(l_lThisDiagramOnly,l_iDiagramPk,0))
        SaveUserSetting("NavigationControl"          ,iif(l_lNavigationControl,"T","F")          ,iif(l_lThisDiagramOnly,l_iDiagramPk,0))
        SaveUserSetting("UnknownInGray"              ,iif(l_lUnknownInGray,"T","F")              ,iif(l_lThisDiagramOnly,l_iDiagramPk,0))
        SaveUserSetting("NeverShowDescriptionOnHover",iif(l_lNeverShowDescriptionOnHover,"T","F"),iif(l_lThisDiagramOnly,l_iDiagramPk,0))

        if empty(l_cErrorMessage)  // Currently there are no scenarios that would create an error, but kept the logic in case in the future will need to handle this.
            l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)
        else
            l_hValues["ThisDiagramOnly"]             := l_lThisDiagramOnly
            l_hValues["DiagramInfoScale"]            := l_nDiagramInfoScale
            l_hValues["CanvasWidth"]                 := l_iCanvasWidth
            l_hValues["CanvasHeight"]                := l_iCanvasHeight
            l_hValues["NavigationControl"]           := l_lNavigationControl
            l_hValues["UnknownInGray"]               := l_lUnknownInGray
            l_hValues["NeverShowDescriptionOnHover"] := l_lNeverShowDescriptionOnHover

            l_cHtml := DataDictionaryVisualizeMyDiagramSettingsBuild(par_iApplicationPk,l_cErrorMessage,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk,l_hValues)
        endif
    endif

case l_cActionOnSubmit == "Cancel"
    l_cHtml += DataDictionaryVisualizeDiagramBuild(par_iApplicationPk,par_cErrorText,par_cApplicationName,par_cURLApplicationLinkCode,l_iDiagramPk)

endcase

return l_cHtml
//=================================================================================================================
function GetDDInfoDuringVisualization()
local l_cHtml := []
local l_cInfo := Strtran(oFcgi:GetQueryString("info"),[%22],["])
local l_iDiagramPk := val(oFcgi:GetQueryString("diagrampk"))
local l_hOnClickInfo := {=>}
local l_nLengthDecoded
local l_aNodes
local l_aEdges
local l_aItems
local l_iTablePk
local l_iColumnPk
local l_oDB_Diagram                      := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_Application                  := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_InArray                      := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfRelatedTables          := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfCurrentTablesInDiagram := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfColumns                := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfEnumValues             := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_ListOfOtherDiagrams          := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_oDB_TableCustomFields            := hb_SQLData(oFcgi:p_o_SQLConnection)
local l_aSQLResult := {}
local l_cSitePath := oFcgi:p_cSitePath
local l_cApplicationLinkCode
local l_cNamespaceName
local l_cTableName
local l_cTableAKA
local l_lTableUnlogged
local l_cTableDescription
local l_cTableInformation
local l_nTableUseStatus
local l_nTableDocStatus
local l_cColumnName
local l_cColumnAKA
local l_nColumnUseStatus
local l_nColumnDocStatus
local l_cColumnDescription
local l_cColumnForeignKeyUse
local l_lColumnForeignKeyOptional
local l_nColumnOnDelete
local l_cFrom_Namespace_Name
local l_cFrom_Table_Name
local l_cFrom_Table_AKA
local l_cTo_Namespace_Name
local l_cTo_Table_Name
local l_cTo_Table_AKA
local l_cRelatedTablesKey
local l_hRelatedTables := {=>}
local l_aRelatedTableInfo
local l_CheckBoxId
local l_nNumberOfTablesInDiagram
local l_cListOfRelatedTablePks := ""
local l_nActiveTabNumber := max(1,min(4,val(oFcgi:GetCookieValue("DiagramDetailTab"))))
local l_nEdgeNumber
local l_nEdgeCounter
local l_nNumberOfColumns
local l_nNumberOfOtherDiagram
local l_nNumberOfRelatedTables
local l_cUseStatus
local l_cDocStatus
local l_nNumberOfCustomFieldValues
local l_hOptionValueToDescriptionMapping := {=>}
local l_cHtml_TableCustomFields := ""
local l_lUnknownInGray               := (GetUserSetting("UnknownInGray") == "T")
local l_lNeverShowDescriptionOnHover := (GetUserSetting("NeverShowDescriptionOnHover") == "T")
local l_oData_Application
local l_cApplicationSupportColumns
local l_cHtml_icon
local l_cHtml_tr_class
local l_nAccessLevelDD := 1   // None by default
local l_iApplicationPk
local l_cDisabled
local l_cObjectId
local l_lFoundData
local l_nRenderMode
local l_oDataDiagram
local l_cTooltipEnumValues
local l_nColspan
local l_lWarnings := .f.

//oFcgi:p_nAccessLevelDD

oFcgi:TraceAdd("GetDDInfoDuringVisualization")

with object l_oDB_Diagram
    :Table("f8632e51-09a7-4ee7-bc76-517c490f505a","Diagram")
    :Column("Diagram.RenderMode"         ,"Diagram_RenderMode")
    l_oDataDiagram := :Get(l_iDiagramPk)
    l_nRenderMode := max(RENDERMODE_VISJS,l_oDataDiagram:Diagram_RenderMode)
endwith

hb_HKeepOrder(l_hRelatedTables,.f.) // Will order the hash by its key, with will be entered as upper case. For Keys stored as Strings they will need to be the same length

// l_cHtml += [Hello World c2 - ]+hb_TtoS(hb_DateTime())+[  ]+l_cInfo

l_nLengthDecoded := hb_jsonDecode(l_cInfo,@l_hOnClickInfo)

// if l_hOnClickInfo["nodes"]  is an array. if len is 1 we have the table.pk
// if l_hOnClickInfo["nodes"] is a 0 size array and l_hOnClickInfo["edges"] array of len 1   will be column.pk

// SendToDebugView("TabCookie = "+oFcgi:GetCookieValue("DiagramDetailTab"))

l_aNodes := hb_HGetDef(l_hOnClickInfo,"nodes",{})
if len(l_aNodes) == 1
    l_iTablePk := val(substr(l_aNodes[1],2))

    with object l_oDB_Application
        :Table("51edf270-d3d3-4c8b-b530-c2d3b90c93c1","Table")
        :Column("Application.pk"             , "Application_pk")
        :Column("Application.SupportColumns" , "Application_SupportColumns")
        :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
        :Join("inner","Application","","Namespace.fk_Application = Application.pk")
        l_oData_Application := :Get(l_iTablePk)
// SendToDebugView(:GetLastEventId(),:LastSQL())
        l_lFoundData := (:Tally == 1)
    endwith

    if !l_lFoundData
        l_cHtml += [<div  class="alert alert-danger" role="alert m-3">Could not find table.</div>]

    else

        l_cApplicationSupportColumns := nvl(l_oData_Application:Application_SupportColumns,"")

        //Get the applicable l_nAccessLevelDD
        l_iApplicationPk := l_oData_Application:Application_pk

        l_nAccessLevelDD := GetAccessLevelDDForApplication(l_iApplicationPk)

        //Clicked on a table

        // _M_ Refactor following code once orm supports unions and CTE (common Table Expressions)

        //Current List of tables in diagram
        with Object l_oDB_ListOfCurrentTablesInDiagram
            :Table("c83a242a-622c-43c7-9e10-31316b16c7d4","DiagramTable")
            :Distinct(.t.)
            :Column("Table.pk","pk")
            :Column("DiagramTable.pk","DiagramTable_pk")
            :Join("inner","Table","","DiagramTable.fk_Table = Table.pk")
            :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
            :Where("DiagramTable.fk_Diagram = ^" , l_iDiagramPk)
            :SQL("ListOfCurrentTablesInDiagram")
// SendToDebugView(:GetLastEventId(),:LastSQL())

            l_nNumberOfTablesInDiagram := :Tally
            if l_nNumberOfTablesInDiagram > 0
                with object :p_oCursor
                    :Index("pk","pk")
                    :CreateIndexes()
                    :SetOrder("pk")
                endwith
            endif
            // ExportTableToHtmlFile("ListOfCurrentTablesInDiagram",OUTPUT_FOLDER+hb_ps()+"PostgreSQL_ListOfCurrentTablesInDiagram.html","From PostgreSQL",,25,.t.)
        endwith


        with object l_oDB_ListOfColumns
            :Table("4d84f290-c1f8-42f1-a2b0-e41244ccdfd2","Column")
            :Column("Column.pk"                  ,"pk")
            :Column("Column.Name"                ,"Column_Name")
            :Column("Column.AKA"                 ,"Column_AKA")
            :Column("Column.UsedAs"              ,"Column_UsedAs")
            :Column("Column.UsedBy"              ,"Column_UsedBy")
            :Column("Column.UseStatus"           ,"Column_UseStatus")
            :Column("Column.DocStatus"           ,"Column_DocStatus")
            :Column("Column.Description"         ,"Column_Description")
            :Column("Column.Order"               ,"Column_Order")
            :Column("Column.Type"                ,"Column_Type")
            :Column("Column.Array"               ,"Column_Array")
            :Column("Column.Length"              ,"Column_Length")
            :Column("Column.Scale"               ,"Column_Scale")
            :Column("Column.Nullable"            ,"Column_Nullable")
            :Column("Column.ForeignKeyOptional"  ,"Column_ForeignKeyOptional")
            :Column("Column.OnDelete"            ,"Column_OnDelete")
            :Column("Column.DefaultType"         ,"Column_DefaultType")
            :Column("Column.DefaultCustom"       ,"Column_DefaultCustom")
            :Column("Column.Unicode"             ,"Column_Unicode")
            :Column("Column.fk_TableForeign"     ,"Column_fk_TableForeign")
            :Column("Column.ForeignKeyUse"       ,"Column_ForeignKeyUse")
            :Column("Column.ForeignKeyOptional"  ,"Column_ForeignKeyOptional")
            :Column("Column.fk_Enumeration"      ,"Column_fk_Enumeration")
            :Column("Column.TestWarning"         ,"Column_TestWarning")
            
            :Column("Namespace.Name"             ,"Namespace_Name")
            :Column("Table.Name"                 ,"Table_Name")
            :Column("Table.AKA"                  ,"Table_AKA")
            :Column("Enumeration.Name"           ,"Enumeration_Name")
            :Column("Enumeration.AKA"            ,"Enumeration_AKA")
            :Column("Enumeration.ImplementAs"    ,"Enumeration_ImplementAs")
            :Column("Enumeration.ImplementLength","Enumeration_ImplementLength")
            
            :Join("left","Table"      ,"","Column.fk_TableForeign = Table.pk")
            :Join("left","Namespace"  ,"","Table.fk_Namespace = Namespace.pk")
            :Join("left","Enumeration","","Column.fk_Enumeration  = Enumeration.pk")
            :Where("Column.fk_Table = ^",l_iTablePk)
            :OrderBy("Column_Order")
            :SQL("ListOfColumns")
            // SendToClipboard(:LastSQL())
            l_nNumberOfColumns := :Tally
        endwith

        if l_nNumberOfColumns > 1

            select ListOfColumns
            scan all while !l_lWarnings
                if !empty(nvl(ListOfColumns->Column_TestWarning,""))
                    l_lWarnings := .t.
                endif
            endscan

            with object l_oDB_ListOfEnumValues
                :Table("3784d627-8099-4966-b66e-d177304a3310","Column")
                :Column("Column.pk"                     ,"Column_pk")

                :Column("EnumValue.Order"               ,"EnumValue_Order")
                :Column("EnumValue.Number"              ,"EnumValue_Number")
                :Column("EnumValue.Name"                ,"EnumValue_Name")
                :Column("EnumValue.AKA"                 ,"EnumValue_AKA")
                :Column("EnumValue.Description"         ,"EnumValue_Description")
                :Column("EnumValue.UseStatus"           ,"EnumValue_UseStatus")
                
                :Join("inner","EnumValue","","Column.fk_Enumeration > 0 and Column.fk_Enumeration = EnumValue.fk_Enumeration")
                :Where("Column.fk_Table = ^",l_iTablePk)

                :OrderBy("Column_pk")
                :OrderBy("EnumValue_Order")
                :SQL("ListOfEnumValues")
                with object :p_oCursor
                    :Index("tag1","padr(alltrim(str(Column_pk))+'*'+str(EnumValue_Order,10),40)")
                    :CreateIndexes()
                endwith
            endwith
        endif

        with object l_oDB_ListOfOtherDiagrams
            :Table("d7bf79b7-d7bf-435d-ab83-3d02fcbc6612","DiagramTable")
            :Column("Diagram.pk"         ,"Diagram_pk")
            :Column("Diagram.Name"       ,"Diagram_Name")
            :Column("Diagram.LinkUID"    ,"Diagram_LinkUID")
            :Column("upper(Diagram.Name)","tag1")
            :Join("inner","Diagram","","DiagramTable.fk_Diagram = Diagram.pk")
            :Where("DiagramTable.fk_Table = ^",l_iTablePk)
            :Where("Diagram.pk <> ^",l_iDiagramPk)
            :OrderBy("tag1")
            :SQL("ListOfOtherDiagram")
            l_nNumberOfOtherDiagram := :Tally
        endwith


        //Get the list of related tables
        with object l_oDB_ListOfRelatedTables
            // Parent Of
            :Table("c9f6365d-fa6e-496d-95f9-c0266c79df49","Column")
            :Distinct(.t.)
            :Column("Table.pk"       , "Table_pk")
            :Column("Namespace.Name" , "Namespace_Name")
            :Column("Namespace.AKA"  , "Namespace_AKA")
            :Column("Table.Name"     , "Table_Name")
            :Column("Table.AKA"      , "Table_AKA")
            :Column("upper(Namespace.Name)" , "tag1")
            :Column("upper(Table.Name)"     , "tag2")
            :Where("Column.fk_TableForeign = ^" , l_iTablePk)
            :Join("inner","Table","","Column.fk_Table = Table.pk")
            :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
            :OrderBy("tag1")
            :OrderBy("tag2")
            :SQL("ListOfRelatedTables")
            if :Tally > 0
                select ListOfRelatedTables
                scan all
                    l_cRelatedTablesKey := padr(ListOfRelatedTables->tag1,200)+padr(ListOfRelatedTables->tag2,200)
                    l_hRelatedTables[l_cRelatedTablesKey] := {(l_nNumberOfTablesInDiagram <= 0) .or. VFP_Seek(ListOfRelatedTables->Table_pk,"ListOfCurrentTablesInDiagram","pk"),;  // If table already included in diagram
                                                            ListOfRelatedTables->Table_pk,;
                                                            ListOfRelatedTables->Namespace_Name,;
                                                            ListOfRelatedTables->Namespace_AKA,;
                                                            ListOfRelatedTables->Table_Name,;
                                                            ListOfRelatedTables->Table_AKA,;
                                                            .t.,.f.}   // Parent Of, Child Of
                endscan
            endif

            // Child Of
            :Table("6df92604-281c-4ec0-91fa-03074b4bf8dd","Column")
            :Distinct(.t.)
            :Column("Table.pk"       , "Table_pk")
            :Column("Namespace.Name" , "Namespace_Name")
            :Column("Namespace.AKA"  , "Namespace_AKA")
            :Column("Table.Name"     , "Table_Name")
            :Column("Table.AKA"      , "Table_AKA")
            :Column("upper(Namespace.Name)" , "tag1")
            :Column("upper(Table.Name)"     , "tag2")
            :Where("Column.fk_Table = ^" , l_iTablePk)
            :Join("inner","Table","","Column.fk_TableForeign = Table.pk")
            :Join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
            :OrderBy("tag1")
            :OrderBy("tag2")
            :SQL("ListOfRelatedTables")

            if :Tally > 0
                select ListOfRelatedTables
                scan all
                    l_cRelatedTablesKey := padr(ListOfRelatedTables->tag1,200)+padr(ListOfRelatedTables->tag2,200)
                    l_aRelatedTableInfo := hb_HGetDef(l_hRelatedTables,l_cRelatedTablesKey,{})
                    if empty(len(l_aRelatedTableInfo))
                        //The table was not already a "Parent Of"
                        l_hRelatedTables[l_cRelatedTablesKey] := {(l_nNumberOfTablesInDiagram <= 0) .or. VFP_Seek(ListOfRelatedTables->Table_pk,"ListOfCurrentTablesInDiagram","pk"),;  // If table already included in diagram
                                                                ListOfRelatedTables->Table_pk,;
                                                                ListOfRelatedTables->Namespace_Name,;
                                                                ListOfRelatedTables->Namespace_AKA,;
                                                                ListOfRelatedTables->Table_Name,;
                                                                ListOfRelatedTables->Table_AKA,;
                                                                .f.,;    // Parent Of
                                                                .t.  }   // Child Of    8th array element
                    else
                        l_hRelatedTables[l_cRelatedTablesKey][8] := .t.
                    endif
                endscan
            endif

            l_nNumberOfRelatedTables := len(l_hRelatedTables)
            CloseAlias("ListOfRelatedTables")   // Not really needed since orm will auto-close cursors, but still added this for clarity.
        endwith

        with object l_oDB_TableCustomFields

            // Get the Table Custom Fields
            :Table("8a952e50-5751-4a85-a542-e543d42db2d7","CustomFieldValue")
            :Distinct(.t.)
            :Column("CustomField.pk"              ,"CustomField_pk")
            :Column("CustomField.OptionDefinition","CustomField_OptionDefinition")
            :Join("inner","CustomField"     ,"","CustomFieldValue.fk_CustomField = CustomField.pk")
            :Where("CustomFieldValue.fk_Entity = ^",l_iTablePk)
            :Where("CustomField.UsedOn = ^",USEDON_TABLE)
            :Where("CustomField.Status <= 2")
            :Where("CustomField.Type = 2")   // Multi Choice
            :SQL("ListOfCustomFieldOptionDefinition")
            if :Tally > 0
                CustomFieldLoad_hOptionValueToDescriptionMapping(@l_hOptionValueToDescriptionMapping)
            endif

            :Table("efab8dc2-6996-4608-ae9d-18c36716f45f","CustomFieldValue")
            :Column("CustomFieldValue.fk_Entity","fk_entity")
            :Column("CustomField.pk"            ,"CustomField_pk")
            :Column("CustomField.Label"         ,"CustomField_Label")
            :Column("CustomField.Type"          ,"CustomField_Type")
            :Column("CustomFieldValue.ValueI"   ,"CustomFieldValue_ValueI")
            :Column("CustomFieldValue.ValueM"   ,"CustomFieldValue_ValueM")
            :Column("CustomFieldValue.ValueD"   ,"CustomFieldValue_ValueD")
            :Column("upper(CustomField.Name)"   ,"tag1")
            :Join("inner","CustomField"     ,"","CustomFieldValue.fk_CustomField = CustomField.pk")
            :Where("CustomFieldValue.fk_Entity = ^",l_iTablePk)
            :Where("CustomField.UsedOn = ^",USEDON_TABLE)
            :Where("CustomField.Status <= 2")
            :OrderBy("tag1")
            :SQL("ListOfCustomFieldValues")
            l_nNumberOfCustomFieldValues := :Tally
            
            if l_nNumberOfCustomFieldValues > 0
                l_cHtml_TableCustomFields := CustomFieldsBuildGridOther(l_iTablePk,l_hOptionValueToDescriptionMapping)
            endif

            // Get the Column Custom Fields
            // l_hOptionValueToDescriptionMapping := {=>}
            hb_HClear(l_hOptionValueToDescriptionMapping)

            :Table("f50e23e7-1bbc-495a-97ac-ed178f89a0a3","Column")
            :Distinct(.t.)
            :Column("CustomField.pk"              ,"CustomField_pk")
            :Column("CustomField.OptionDefinition","CustomField_OptionDefinition")
            :Join("inner","CustomFieldValue","","CustomFieldValue.fk_Entity = Column.pk")
            :Join("inner","CustomField"     ,"","CustomFieldValue.fk_CustomField = CustomField.pk")
            :Where("Column.fk_Table = ^",l_iTablePk)
            :Where("CustomField.UsedOn = ^",USEDON_COLUMN)
            :Where("CustomField.Status <= 2")
            :Where("CustomField.Type = 2")   // Multi Choice
            :SQL("ListOfCustomFieldOptionDefinition")
            if :Tally > 0
                CustomFieldLoad_hOptionValueToDescriptionMapping(@l_hOptionValueToDescriptionMapping)
            endif

            :Table("d769203a-7556-4288-ad52-f4bf641ee516","Column")
            :Column("Column.pk"              ,"fk_entity")
            :Column("CustomField.pk"         ,"CustomField_pk")
            :Column("CustomField.Label"      ,"CustomField_Label")
            :Column("CustomField.Type"       ,"CustomField_Type")
            :Column("CustomFieldValue.ValueI","CustomFieldValue_ValueI")
            :Column("CustomFieldValue.ValueM","CustomFieldValue_ValueM")
            :Column("CustomFieldValue.ValueD","CustomFieldValue_ValueD")
            :Column("upper(CustomField.Name)","tag1")
            :Join("inner","CustomFieldValue","","CustomFieldValue.fk_Entity = Column.pk")
            :Join("inner","CustomField"     ,"","CustomFieldValue.fk_CustomField = CustomField.pk")
            :Where("Column.fk_Table = ^",l_iTablePk)
            :Where("CustomField.UsedOn = ^",USEDON_COLUMN)
            :Where("CustomField.Status <= 2")
            // :OrderBy("Column_pk")
            :OrderBy("tag1")
            :SQL("ListOfCustomFieldValues")
            l_nNumberOfCustomFieldValues := :Tally

        endwith

        with object l_oDB_InArray
            :Table("da9443c6-bffe-4ccd-bded-c3a7221bac9f","Table")
            :Column("Application.LinkCode","Application_LinkCode")  // 1
            :Column("Namespace.name"      ,"Namespace_Name")        // 2
            :Column("Table.Name"          ,"Table_Name")            // 3
            :Column("Table.AKA"           ,"Table_AKA")             // 4
            :Column("Table.Unlogged"      ,"Table_Unlogged")        // 5
            :Column("Table.Description"   ,"Table_Description")     // 6
            :Column("Table.Information"   ,"Table_Information")     // 7
            :Column("Table.UseStatus"     ,"Table_UseStatus")       // 8
            :Column("Table.DocStatus"     ,"Table_DocStatus")       // 9
            :join("inner","Namespace","","Table.fk_Namespace = Namespace.pk")
            :join("inner","Application","","Namespace.fk_Application = Application.pk")
            :Where("Table.pk = ^" , l_iTablePk)
            :SQL(@l_aSQLResult)
        endwith

        if l_oDB_InArray:Tally == 1
            l_cApplicationLinkCode := AllTrim(l_aSQLResult[1,1])
            l_cNamespaceName       := AllTrim(l_aSQLResult[1,2])
            l_cTableName           := AllTrim(l_aSQLResult[1,3])
            l_cTableAKA            := AllTrim(nvl(l_aSQLResult[1,4],""))
            l_lTableUnlogged       := l_aSQLResult[1,5]
            l_cTableDescription    := nvl(l_aSQLResult[1,6],"")
            l_cTableInformation    := nvl(l_aSQLResult[1,7],"")
            l_nTableUseStatus      := l_aSQLResult[1,8]
            l_nTableDocStatus      := l_aSQLResult[1,9]

            l_cUseStatus := {"","Proposed","Under Development","Active","To Be Discontinued","Discontinued"}[iif(vfp_between(l_nTableUseStatus,USESTATUS_UNKNOWN,USESTATUS_DISCONTINUED),l_nTableUseStatus,USESTATUS_UNKNOWN)]
            l_cDocStatus := {"","Not Needed","Composing","Completed"}[iif(vfp_between(l_nTableDocStatus,DOCTATUS_MISSING,DOCTATUS_COMPLETE),l_nTableDocStatus,DOCTATUS_MISSING)]

            l_cHtml += [<nav class="navbar navbar-light" style="background-color: #]
            do case
            case l_nTableUseStatus <= USESTATUS_UNKNOWN
                if l_lUnknownInGray
                    l_cHtml += USESTATUS_1_NODE_HIGHLIGHT
                else
                    l_cHtml += USESTATUS_4_NODE_HIGHLIGHT
                endif
            case l_nTableUseStatus == USESTATUS_PROPOSED
                l_cHtml += USESTATUS_2_NODE_HIGHLIGHT
            case l_nTableUseStatus == USESTATUS_UNDERDEVELOPMENT
                l_cHtml += USESTATUS_3_NODE_HIGHLIGHT
            case l_nTableUseStatus == USESTATUS_ACTIVE
                l_cHtml += USESTATUS_4_NODE_HIGHLIGHT
            case l_nTableUseStatus == USESTATUS_TOBEDISCONTINUED
                l_cHtml += USESTATUS_5_NODE_HIGHLIGHT
            case l_nTableUseStatus >= USESTATUS_DISCONTINUED
                l_cHtml += USESTATUS_6_NODE_HIGHLIGHT
            endcase
            l_cHtml += [;">]

                l_cHtml += [<div class="input-group">]
                    //Added extra double quotes around table names it easier to select text on double click.
                    l_cHtml += [<span class="navbar-brand ms-3">Table: "]+l_cNamespaceName+[.]+l_cTableName+["]+;
                                iif(l_lTableUnlogged,[ UNLOGGED],[])+;
                                FormatAKAForDisplay(l_cTableAKA)+;
                                [<a class="ms-3" target="_blank" href="]+l_cSitePath+[DataDictionaries/EditTable/]+l_cApplicationLinkCode+"/"+l_cNamespaceName+"/"+l_cTableName+[/"><i class="bi bi-pencil-square"></i></a>]
                                if !empty(l_cUseStatus) // .and. l_cUseStatus != "Active"
                                    l_cHtml += [<span class="ms-3 fs-6">]+l_cUseStatus+[</span>]
                                endif
                    l_cHtml += [</span>]
                l_cHtml += [</div>]

            l_cHtml += [</nav>]

            l_cHtml += [<div class="m-3"></div>]

            l_cHtml += [<ul class="nav nav-tabs">]
                l_cHtml += [<li class="nav-item">]
                    l_cHtml += [<a id="TabDetail1" class="nav-link]+iif(l_nActiveTabNumber == 1,[ active],[])+["]+;
                                    [ onclick="document.cookie = 'DiagramDetailTab=1; path=/';]+;
                                                                [$('#DetailType1').show();]+;
                                                                [$('#DetailType2').hide();]+;
                                                                [$('#DetailType3').hide();]+;
                                                                [$('#DetailType4').hide();]+;
                                                                [$('#TabDetail1').addClass('active');]+;
                                                                [$('#TabDetail2').removeClass('active');]+;
                                                                [$('#TabDetail3').removeClass('active');]+;
                                                                [$('#TabDetail4').removeClass('active');"]+;
                                                                [>Columns (]+Trans(l_nNumberOfColumns)+[)</a>]
                l_cHtml += [</li>]
                l_cHtml += [<li class="nav-item">]
                    l_cHtml += [<a id="TabDetail2" class="nav-link]+iif(l_nActiveTabNumber == 2,[ active],[])+["]+;
                                    [ onclick="document.cookie = 'DiagramDetailTab=2; path=/';]+;
                                                                [$('#DetailType1').hide();]+;
                                                                [$('#DetailType2').show();]+;
                                                                [$('#DetailType3').hide();]+;
                                                                [$('#DetailType4').hide();]+;
                                                                [$('#TabDetail1').removeClass('active');]+;
                                                                [$('#TabDetail2').addClass('active');]+;
                                                                [$('#TabDetail3').removeClass('active');]+;
                                                                [$('#TabDetail4').removeClass('active');"]+;
                                                                [>Related Tables In App (]+Trans(l_nNumberOfRelatedTables)+[)</a>]
                l_cHtml += [</li>]
                l_cHtml += [<li class="nav-item">]
                    l_cHtml += [<a id="TabDetail3" class="nav-link]+iif(l_nActiveTabNumber == 3,[ active],[])+["]+;
                                    [ onclick="document.cookie = 'DiagramDetailTab=3; path=/';]+;
                                                                [$('#DetailType1').hide();]+;
                                                                [$('#DetailType2').hide();]+;
                                                                [$('#DetailType3').show();]+;
                                                                [$('#DetailType4').hide();]+;
                                                                [$('#TabDetail1').removeClass('active');]+;
                                                                [$('#TabDetail2').removeClass('active');]+;
                                                                [$('#TabDetail3').addClass('active');]+;
                                                                [$('#TabDetail4').removeClass('active');"]+;
                                                                [>Other Diagrams (]+Trans(l_nNumberOfOtherDiagram)+[)</a>]
                l_cHtml += [</li>]
                l_cHtml += [<li class="nav-item">]
                    l_cHtml += [<a id="TabDetail4" class="nav-link]+iif(l_nActiveTabNumber == 4,[ active],[])+["]+;
                                    [ onclick="document.cookie = 'DiagramDetailTab=4; path=/';]+;
                                                                [$('#DetailType1').hide();]+;
                                                                [$('#DetailType2').hide();]+;
                                                                [$('#DetailType3').hide();]+;
                                                                [$('#DetailType4').show();]+;
                                                                [$('#TabDetail1').removeClass('active');]+;
                                                                [$('#TabDetail2').removeClass('active');]+;
                                                                [$('#TabDetail3').removeClass('active');]+;
                                                                [$('#TabDetail4').addClass('active');"]+;
                                                                [>Table Info</a>]
                l_cHtml += [</li>]
            l_cHtml += [</ul>]

            l_cHtml += [<div class="m-3"></div>]

            // -----------------------------------------------------------------------------------------------------------------------------------------
            l_cHtml += [<div id="DetailType1"]+iif(l_nActiveTabNumber <> 1,[ style="display: none;"],[])+[ class="m-3">]


                if l_nNumberOfColumns <= 0
                    l_cHtml += [<div class="mb-2">Table has no columns</div>]
                else
                    l_cHtml += [<div class="row">]  //  justify-content-center
                        l_cHtml += [<div class="col-auto">]

                            l_cHtml += [<div>]
                            l_cHtml += [<span>Filter on Column Name</span>]
                            l_cHtml += [<input type="text" id="ColumnSearch" value="" size="30" class="ms-2">]
                            l_cHtml += [<span class="ms-1"> (Press Enter)</span>]
                            l_cHtml += [<input type="button" id="ButtonShowAll" class="btn btn-primary rounded ms-3" value="All">]
                            l_cHtml += [<input type="button" id="ButtonShowCoreOnly" class="btn btn-primary rounded ms-3" value="Core Only">]
                            l_cHtml += [</div>]

                            l_cHtml += [<div class="m-3"></div>]

                            l_cHtml += [<table class="table table-sm table-bordered">]   // table-striped

                            l_cHtml += [<tr class="bg-primary bg-gradient">]
                                l_cHtml += [<th></th>]
                                l_cHtml += [<th class="text-white">Name</th>]
                                l_cHtml += [<th class="text-white">Type</th>]
                                l_cHtml += [<th class="text-white">Nullable</th>]
                                l_cHtml += [<th class="text-white">Default</th>]
                                l_cHtml += [<th class="text-white">Foreign Key<br>To/Use/Optional</th>]
                                l_cHtml += [<th class="text-white">On Delete</th>]
                                l_cHtml += [<th class="text-white">Description</th>]
                                l_cHtml += [<th class="text-white text-center">Usage<br>Status</th>]
                                l_cHtml += [<th class="text-white text-center">Doc<br>Status</th>]
                                l_cHtml += [<th class="text-white">Used By</th>]
                                if l_nNumberOfCustomFieldValues > 0
                                    l_cHtml += [<th class="text-white text-center">Other</th>]
                                endif
                                if l_lWarnings
                                    l_cHtml += [<th class="text-center bg-warning text-danger">Warning</th>]
                                endif
                            l_cHtml += [</tr>]

                            select ListOfColumns
                            scan all

                                do case
                                case ListOfColumns->Column_UsedAs = 2
                                    l_cHtml_icon     := [<i class="bi bi-key"></i>]
                                    l_cHtml_tr_class := "ColumnNotCore"
                                case ListOfColumns->Column_UsedAs = 4 .or. " "+ListOfColumns->Column_Name+" " $ " "+l_cApplicationSupportColumns+" "
                                    l_cHtml_icon     := [<i class="bi bi-tools"></i>]
                                    l_cHtml_tr_class := "ColumnNotCore"
                                // case !hb_IsNIL(ListOfColumns->Table_Name)
                                case ListOfColumns->Column_UsedAs = 3
                                    // l_cHtml_icon     := [<i class="bi-arrow-left"></i>]
                                    if ListOfColumns->Column_ForeignKeyOptional
                                        l_cHtml_icon     := [<i class="bi-arrow-bar-right"></i>]
                                    else
                                        l_cHtml_icon     := [<i class="bi-arrow-right"></i>]
                                    endif
                                    l_cHtml_tr_class := "ColumnNotCore"
                                otherwise
                                    l_cHtml_icon     := []
                                    l_cHtml_tr_class := "ColumnCore"
                                endcase

                                l_cHtml += [<tr class="]+l_cHtml_tr_class+["]+GetTRStyleBackgroundColorUseStatus(recno(),ListOfColumns->Column_UseStatus)+[>]

                                    l_cHtml += [<td class="GridDataControlCells text-center" valign="top">]+l_cHtml_icon+[</td>]

                                    // Name
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += [<a target="_blank" href="]+l_cSitePath+[DataDictionaries/EditColumn/]+l_cApplicationLinkCode+"/"+l_cNamespaceName+"/"+l_cTableName+[/]+ListOfColumns->Column_Name+[/"><span class="SpanColumnName">]+ListOfColumns->Column_Name+FormatAKAForDisplay(ListOfColumns->Column_AKA)+[</span></a>]
                                    l_cHtml += [</td>]

                                    // Type
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]

                                        // Prepare the tooltip text for enumeration type fields
                                        if allt(ListOfColumns->Column_Type) == "E" .and. vfp_seek(trans(ListOfColumns->pk)+'*',"ListOfEnumValues","tag1")
                                            l_cTooltipEnumValues := [<table>]
                                            select ListOfEnumValues
                                            scan while ListOfEnumValues->Column_pk == ListOfColumns->pk
                                                l_cTooltipEnumValues += [<tr]+strtran(GetTRStyleBackgroundColorUseStatus(0,ListOfEnumValues->EnumValue_UseStatus,"1.0"),["],['])+[>]
                                                l_cTooltipEnumValues += [<td style='text-align:left'>]+hb_StrReplace(ListOfEnumValues->EnumValue_Name+FormatAKAForDisplay(ListOfEnumValues->EnumValue_AKA),;
                                                            {[ ]=>[&nbsp;],;
                                                            ["]=>[&#34;],;
                                                            [']=>[&#39;],;
                                                            [<]=>[&lt;],;
                                                            [>]=>[&gt;]})+[</td>]
                                                l_cTooltipEnumValues += [<td>]+iif(hb_orm_isnull("ListOfEnumValues","EnumValue_Number"),"","&nbsp;"+trans(ListOfEnumValues->EnumValue_Number))+[</td>]
                                                if !hb_orm_isnull("ListOfEnumValues","EnumValue_Description") .and. !empty(ListOfEnumValues->EnumValue_Description)
                                                    l_cTooltipEnumValues += [<td>&nbsp;...&nbsp;</td>]
                                                else
                                                    l_cTooltipEnumValues += [<td></td>]
                                                endif
                                                l_cTooltipEnumValues += [</tr>]
                                            endscan
                                            l_cTooltipEnumValues += [</table>]
                                        else
                                            l_cTooltipEnumValues := ""
                                        endif

                                        l_cHtml += FormatColumnTypeInfo(allt(ListOfColumns->Column_Type),;
                                                                        ListOfColumns->Column_Length,;
                                                                        ListOfColumns->Column_Scale,;
                                                                        ListOfColumns->Enumeration_Name,;
                                                                        ListOfColumns->Enumeration_AKA,;
                                                                        ListOfColumns->Enumeration_ImplementAs,;
                                                                        ListOfColumns->Enumeration_ImplementLength,;
                                                                        ListOfColumns->Column_Unicode,;
                                                                        l_cSitePath,;
                                                                        l_cApplicationLinkCode,;
                                                                        l_cNamespaceName,;
                                                                        l_cTooltipEnumValues)
                                        if ListOfColumns->Column_Array
                                            l_cHtml += " [Array]"
                                        endif
                                    l_cHtml += [</td>]

                                    // Nullable
                                    l_cHtml += [<td class="GridDataControlCells text-center" valign="top">]
                                        l_cHtml += iif(ListOfColumns->Column_Nullable,[<i class="bi bi-check-lg"></i>],[&nbsp;])
                                    l_cHtml += [</td>]

                                    // Default
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += GetColumnDefault(.f.,ListOfColumns->Column_Type,ListOfColumns->Column_DefaultType,ListOfColumns->Column_DefaultCustom)
                                    l_cHtml += [</td>]

                                    // Foreign Key To/Use/Optional
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        if !hb_IsNIL(ListOfColumns->Table_Name)
                                            l_cHtml += [<a style="color:#]+COLOR_ON_LINK_NEWPAGE+[ !important;" target="_blank" href="]+l_cSitePath+[DataDictionaries/ListColumns/]+l_cApplicationLinkCode+"/"+ListOfColumns->Namespace_Name+"/"+ListOfColumns->Table_Name+[/">]
                                            l_cHtml += ListOfColumns->Namespace_Name+[.]+ListOfColumns->Table_Name+FormatAKAForDisplay(ListOfColumns->Table_AKA)
                                            l_cHtml += [</a>]
                                            if !hb_IsNIL(ListOfColumns->Column_ForeignKeyUse)
                                                l_cHtml += [<br>]+ListOfColumns->Column_ForeignKeyUse
                                            endif
                                            if ListOfColumns->Column_ForeignKeyOptional
                                                l_cHtml += [<br>Optional]
                                            endif
                                        endif
                                    l_cHtml += [</td>]

                                    // // Foreign Key Required
                                    // l_cHtml += [<td class="GridDataControlCells text-center" valign="top">]
                                    //     if ListOfColumns->Column_UsedAs == COLUMN_USEDAS_FOREIGN_KEY
                                    //         l_cHtml += {"","Yes","No"}[iif(vfp_between(ListOfColumns->Column_Required,1,3),ListOfColumns->Column_Required,1)]
                                    //     endif
                                    // l_cHtml += [</td>]

                                    // OnDelete
                                    l_cHtml += [<td class="GridDataControlCells text-center" valign="top">]
                                        if ListOfColumns->Column_UsedAs = 3
                                            l_cHtml += {"","Protect","Cascade","Break Link"}[iif(vfp_between(ListOfColumns->Column_OnDelete,1,4),ListOfColumns->Column_OnDelete,1)]
                                        endif
                                    l_cHtml += [</td>]

                                    // Description
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += TextToHtml(hb_DefaultValue(ListOfColumns->Column_Description,""))
                                    l_cHtml += [</td>]

                                    // Use Status
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += {"","Proposed","Under Development","Active","To Be Discontinued","Discontinued"}[iif(vfp_between(ListOfColumns->Column_UseStatus,USESTATUS_UNKNOWN,USESTATUS_DISCONTINUED),ListOfColumns->Column_UseStatus,USESTATUS_UNKNOWN)]
                                    l_cHtml += [</td>]

                                    // Doc Status
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += {"","Not Needed","In Progress","Complete"}[iif(vfp_between(ListOfColumns->Column_DocStatus,DOCTATUS_MISSING,DOCTATUS_COMPLETE),ListOfColumns->Column_DocStatus,DOCTATUS_MISSING)]
                                    l_cHtml += [</td>]

                                    // Used By
                                    l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                        l_cHtml += GetItemInListAtPosition(ListOfColumns->Column_UsedBy,{"","MySQL Only","PostgreSQL Only"},"")
                                    l_cHtml += [</td>]

                                    if l_nNumberOfCustomFieldValues > 0
                                        l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                            l_cHtml += CustomFieldsBuildGridOther(ListOfColumns->pk,l_hOptionValueToDescriptionMapping)
                                        l_cHtml += [</td>]
                                    endif

                                    if l_lWarnings
                                        l_cHtml += [<td class="GridDataControlCells" valign="top">]
                                            l_cHtml += TextToHtml(hb_DefaultValue(ListOfColumns->Column_TestWarning,""))
                                        l_cHtml += [</td>]
                                    endif

                                l_cHtml += [</tr>]
                            endscan
                            l_cHtml += [</table>]
                            
                        l_cHtml += [</div>]
                    l_cHtml += [</div>]

                endif

            l_cHtml += [</div>]

            // -----------------------------------------------------------------------------------------------------------------------------------------

            l_cHtml += [<div id="DetailType2"]+iif(l_nActiveTabNumber <> 2,[ style="display: none;"],[])+[ class="m-3]+iif(l_nNumberOfRelatedTables > 0,[ form-check form-switch],[])+[">]
                if l_nNumberOfRelatedTables <= 0
                    l_cHtml += [<div class="mb-2">Table has no related tables</div>]
                else
                    //---------------------------------------------------------------------------
                    if l_nAccessLevelDD >= 4
                        l_cHtml += [<div class="mb-3"><button id="ButtonSaveLayoutAndSelectedTables" class="btn btn-primary rounded" onclick="]
                        // if GRAPH_LIB_DD == "mxgraph"
                        if l_nRenderMode == RENDERMODE_MXGRAPH
                            l_cHtml += [$('#TextNodePositions').val( JSON.stringify(getPositions(network)) );]
                        // elseif GRAPH_LIB_DD == "visjs"
                        else
                            l_cHtml += [network.storePositions();]
                            l_cHtml += [$('#TextNodePositions').val( JSON.stringify(network.getPositions()) );]
                        endif
                        
                        l_cHtml += [$('#ActionOnSubmit').val('UpdateTableSelectionAndSaveLayout');document.form.submit();]
                        l_cHtml += [">Update Table selection and Save Layout</button></div>]
                        l_cDisabled := ""
                    else
                        l_cDisabled := " disabled"
                    endif
                    //---------------------------------------------------------------------------

                    // l_aRelatedTableInfo
                    //     1 = In Diagram
                    //     2 = table_pk
                    //     3 = Namespace_Name
                    //     4 = Namespace_AKA
                    //     5 = Table_Name
                    //     6 = Table_AKA
                    //     7 = Parent Of
                    //     8 = Child Of
                    l_cHtml += [<table class="">]

                    for each l_aRelatedTableInfo in l_hRelatedTables
                        l_cHtml += [<tr><td>]
                            l_CheckBoxId := "CheckTable"+Trans(l_aRelatedTableInfo[2])
                            if !empty(l_cListOfRelatedTablePks)
                                l_cListOfRelatedTablePks += "*"
                            endif
                            l_cListOfRelatedTablePks += Trans(l_aRelatedTableInfo[2])

                            // l_cHtml += [<input]+UPDATESAVEBUTTON+[ type="checkbox" name="]+l_CheckBoxId+[" id="]+l_CheckBoxId+[" value="1"]+iif(l_aRelatedTableInfo[1]," checked","")+[ class="form-check-input">]
                            l_cHtml += [<input type="checkbox" name="]+l_CheckBoxId+[" id="]+l_CheckBoxId+[" value="1"]+iif(l_aRelatedTableInfo[1]," checked","")+[ class="form-check-input"]+l_cDisabled+[>]

                            l_cHtml += [<label class="form-check-label" for="]+l_CheckBoxId+[">]

                            l_cHtml += l_aRelatedTableInfo[3]+FormatAKAForDisplay(l_aRelatedTableInfo[4])+[.]+l_aRelatedTableInfo[5]+FormatAKAForDisplay(l_aRelatedTableInfo[6])
                            if l_aRelatedTableInfo[8]
                                l_cHtml += [<span class="bi bi-arrow-left ms-2">]
                            endif
                            if l_aRelatedTableInfo[7]
                                l_cHtml += [<span class="bi bi-arrow-right ms-2">]
                            endif

                            l_cHtml += [</label>]

                        l_cHtml += [</td></tr>]
                    endfor

                    l_cHtml += [</table>]

                    l_cHtml += [<input type="hidden" name="TextListOfRelatedTablePks" value="]+l_cListOfRelatedTablePks+[">]
                endif
            l_cHtml += [</div>]

            // -----------------------------------------------------------------------------------------------------------------------------------------

            l_cHtml += [<div id="DetailType3"]+iif(l_nActiveTabNumber <> 3,[ style="display: none;"],[])+[ class="m-3">]
                if l_nNumberOfOtherDiagram <= 0
                    l_cHtml += [<div class="mb-2">Table is not used in other diagrams</div>]
                else
                    select ListOfOtherDiagram
                    scan all
                        l_cHtml += [<div class="mb-2"><a class="link-primary" href="?InitialDiagram=]+ListOfOtherDiagram->Diagram_LinkUID+[" onclick="$('#TextDiagramPk').val(]+Trans(ListOfOtherDiagram->Diagram_pk)+[);$('#ActionOnSubmit').val('Show');document.form.submit();">]+ListOfOtherDiagram->Diagram_Name+[</a></div>]
                    endscan
                endif
            l_cHtml += [</div>]

            // -----------------------------------------------------------------------------------------------------------------------------------------

            l_cHtml += [<div id="DetailType4"]+iif(l_nActiveTabNumber <> 4,[ style="display: none;"],[])+[ class="m-3">]
                //---------------------------------------------------------------------------
                if l_nAccessLevelDD >= 4
                    l_cHtml += [<div class="mb-3"><button id="ButtonSaveLayoutAndDeleteTable" class="btn btn-primary rounded" onclick="]
                    // if GRAPH_LIB_DD == "mxgraph"
                    if l_nRenderMode == RENDERMODE_MXGRAPH
                        l_cHtml += [$('#TextNodePositions').val( JSON.stringify(getPositions(network)) );]
                    // elseif GRAPH_LIB_DD == "visjs"
                    else
                        l_cHtml += [network.storePositions();]
                        l_cHtml += [$('#TextNodePositions').val( JSON.stringify(network.getPositions()) );]
                    endif
                    l_cHtml += [$('#ActionOnSubmit').val('RemoveTableAndSaveLayout');document.form.submit();]
                    l_cHtml += [">Remove Table and Save Layout</button></div>]
                endif
                //---------------------------------------------------------------------------
                l_cHtml += [<input type="hidden" name="TextTablePkToRemove" value="]+Trans(l_iTablePk)+[">]

                if !empty(l_cUseStatus)
                    l_cHtml += [<div class="mt-3"><span class="fs-5">Usage Status:</span><span class="mt-3 ms-2">]+l_cUseStatus+[</span></div>]
                endif

                if !empty(l_cDocStatus)
                    l_cHtml += [<div class="mt-3"><span class="fs-5">Documentation Status:</span><span class="mt-3 ms-2">]+l_cDocStatus+[</span></div>]
                endif

                if !empty(l_cTableDescription)
                    l_cHtml += [<div class="mt-3"><div class="fs-5">Description:</div>]+TextToHTML(l_cTableDescription)+[</div>]
                endif

                if !empty(l_cTableInformation)
                    // l_cHtml += [<div class="mt-3"><div class="fs-5">Information:</div>]+TextToHTML(l_cTableInformation)+[</div>]

                    l_cHtml += [<div class="mt-3">]
                        l_cHtml += [<div class="fs-5">Information:</div>]

                        l_cObjectId := "table-description"+Trans(l_iTablePk)
                        l_cHtml += [<div id="]+l_cObjectId+[">]
                        l_cHtml += [<script> document.getElementById(']+l_cObjectId+[').innerHTML = marked.parse(']+EscapeNewlineAndQuotes(l_cTableInformation)+[');</script>]
                        l_cHtml += [</div>]
                    l_cHtml += [</div>]

                endif

                if !empty(l_cHtml_TableCustomFields)
                    l_cHtml += [<div class="mt-3">]
                        l_cHtml += l_cHtml_TableCustomFields
                    l_cHtml += [</div>]
                endif

            l_cHtml += [</div>]

            // -----------------------------------------------------------------------------------------------------------------------------------------

        endif
    endif
else
    l_aEdges := hb_HGetDef(l_hOnClickInfo,"edges",{})
    if len(l_aEdges) > 0  // If there are multiple edges, meaning like a double arrow, if will only return 1. Have to walk through the "items" instead.
        // l_iColumnPk := l_aEdges[1]

        l_aItems := hb_HGetDef(l_hOnClickInfo,"items",{})
        l_nEdgeNumber := len(l_aItems)

        with object l_oDB_InArray

            for l_nEdgeCounter := 1 to l_nEdgeNumber
                l_iColumnPk := val(substr(hb_HGetDef(l_aItems[l_nEdgeCounter],"edgeId","0"),2))
                if l_iColumnPk > 0

                    :Table("9410bb49-ad19-458f-9a77-b33b29afcccf","Column")

                    :Column("Column.Name"              ,"Column_Name")                 //  1
                    :Column("Column.AKA"               ,"Column_AKA")                  //  2
                    :Column("Column.UseStatus"         ,"Column_UseStatus")            //  3
                    :Column("Column.DocStatus"         ,"Column_DocStatus")            //  4
                    :Column("Column.Description"       ,"Column_Description")          //  5
                    :Column("Column.ForeignKeyUse"     ,"Column_ForeignKeyUse")        //  6
                    :Column("Column.ForeignKeyOptional","Column_ForeignKeyOptional")   //  7
                    :Column("Column.OnDelete"          ,"Column_OnDelete")             //  8
                    
                    :Column("Namespace.Name"   ,"From_Namespace_Name")   //  9
                    :Column("Table.Name"       ,"From_Table_Name")       // 10
                    :Column("Table.AKA"        ,"From_Table_AKA")        // 11
                    :join("inner","Table"      ,"","Column.fk_Table = Table.pk")
                    :join("inner","Namespace"  ,"","Table.fk_Namespace = Namespace.pk")
                    :join("inner","Application","","Namespace.fk_Application = Application.pk")

                    :Column("NamespaceTo.name" , "To_Namespace_Name")    // 12
                    :Column("TableTo.name"     , "To_Table_Name")        // 13
                    :Column("TableTo.AKA"      , "To_Table_AKA")         // 14
                    :Join("inner","Table"    ,"TableTo"    ,"Column.fk_TableForeign = TableTo.pk")
                    :Join("inner","Namespace","NamespaceTo","TableTo.fk_Namespace = NamespaceTo.pk")
                    
                    :Where("Column.pk = ^" , l_iColumnPk)
                    :SQL(@l_aSQLResult)

                    if :Tally != 1
                        l_cHtml += [<div  class="alert alert-danger" role="alert m-3">Could not find relation.</div>]

                    else
                        l_cColumnName               := Alltrim(l_aSQLResult[1,1])
                        l_cColumnAKA                := Alltrim(nvl(l_aSQLResult[1,2],""))
                        l_nColumnUseStatus          := l_aSQLResult[1,3]
                        l_nColumnDocStatus          := l_aSQLResult[1,4]
                        l_cColumnDescription        := Alltrim(nvl(l_aSQLResult[1,5],""))
                        l_cColumnForeignKeyUse      := Alltrim(nvl(l_aSQLResult[1,6],""))
                        l_lColumnForeignKeyOptional := l_aSQLResult[1,7]
                        l_nColumnOnDelete           := l_aSQLResult[1,8]

                        l_cFrom_Namespace_Name := Alltrim(l_aSQLResult[1,9])
                        l_cFrom_Table_Name     := Alltrim(l_aSQLResult[1,10])
                        l_cFrom_Table_AKA      := Alltrim(nvl(l_aSQLResult[1,11],""))

                        l_cTo_Namespace_Name   := Alltrim(l_aSQLResult[1,12])
                        l_cTo_Table_Name       := Alltrim(l_aSQLResult[1,13])
                        l_cTo_Table_AKA        := Alltrim(nvl(l_aSQLResult[1,14],""))

                        l_cHtml += [<nav class="navbar navbar-light" style="background-color: #]
                        do case
                        case l_nColumnUseStatus <= USESTATUS_UNKNOWN
                            l_cHtml += USESTATUS_4_NODE_HIGHLIGHT 
                        case l_nColumnUseStatus == USESTATUS_PROPOSED
                            l_cHtml += USESTATUS_2_NODE_HIGHLIGHT 
                        case l_nColumnUseStatus == USESTATUS_UNDERDEVELOPMENT
                            l_cHtml += USESTATUS_3_NODE_HIGHLIGHT 
                        case l_nColumnUseStatus == USESTATUS_ACTIVE
                            l_cHtml += USESTATUS_4_NODE_HIGHLIGHT 
                        case l_nColumnUseStatus == USESTATUS_TOBEDISCONTINUED
                            l_cHtml += USESTATUS_5_NODE_HIGHLIGHT 
                        case l_nColumnUseStatus >= USESTATUS_DISCONTINUED
                            l_cHtml += USESTATUS_6_NODE_HIGHLIGHT 
                        endcase
                        l_cHtml += [;">]
                            l_cHtml += [<div class="input-group">]
                                //Added extra double quotes around table and column names it easier to select text on double click.
                                l_cHtml += [<span class="navbar-brand ms-3">From: "]+l_cFrom_Namespace_Name+[.]+l_cFrom_Table_Name+FormatAKAForDisplay(l_cFrom_Table_AKA)+["</span>]
                                l_cHtml += [<span class="navbar-brand ms-3">To: "]+l_cTo_Namespace_Name+[.]+l_cTo_Table_Name+FormatAKAForDisplay(l_cTo_Table_AKA)+["</span>]
                                l_cHtml += [<span class="navbar-brand ms-3">Column: "]+l_cColumnName+FormatAKAForDisplay(l_cColumnAKA)+["</span>]
                            l_cHtml += [</div>]
                        l_cHtml += [</nav>]

                        if !empty(l_cColumnForeignKeyUse)
                            l_cHtml += [<div class="m-3"><div class="fs-5">Use:</div>]+l_cColumnForeignKeyUse+[</div>]
                        endif
                        if l_lColumnForeignKeyOptional
                            l_cHtml += [<div class="m-3"><div class="fs-5">Optional:</div>True</div>]
                        endif
                        if l_nColumnOnDelete > 1
                            l_cHtml += [<div class="m-3"><div class="fs-5">On Delete:</div>]
                            l_cHtml += {"","Protect","Cascade","Break Link"}[iif(vfp_between(l_nColumnOnDelete,1,4),l_nColumnOnDelete,1)]
                            l_cHtml += [</div>]
                        endif

                        if !empty(l_cColumnDescription)
                            l_cHtml += [<div class="m-3"><div class="fs-5">Description:</div>]+TextToHTML(l_cColumnDescription)+[</div>]
                        endif

                    endif

                    l_cHtml += [<div class="m-3"></div>]
                endif
            endfor
        endwith
    endif
endif

return l_cHtml
//=================================================================================================================
