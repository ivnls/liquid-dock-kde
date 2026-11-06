// Script do Plasma (executado via org.kde.PlasmaShell.evaluateScript).
// Cria um painel flutuante, centralizado, que se ajusta ao conteúdo, na
// borda inferior da tela principal, contendo apenas o Liquid Glass Dock.
// __THICKNESS__, __HIDING__ e __FORCE__ são substituídos pelo install.sh.

var WIDGET = "com.github.liquidglass.dock";
var force = __FORCE__;

var existing = panels().filter(function (p) {
    return p.location === "bottom" && p.screen === 0;
});

for (var i = 0; i < existing.length; ++i) {
    var ids = existing[i].widgetIds;
    for (var j = 0; j < ids.length; ++j) {
        if (existing[i].widgetById(ids[j]).type === WIDGET) {
            throw new Error("Já existe um painel com o Liquid Glass Dock.");
        }
    }
}

if (existing.length > 0) {
    if (!force) {
        throw new Error("Já existe um painel na borda inferior. Rode novamente com --move-bottom-panel para movê-lo para o topo.");
    }
    for (var k = 0; k < existing.length; ++k) {
        existing[k].location = "top";
    }
}

var panel = new Panel("org.kde.panel");
panel.location = "bottom";
panel.height = __THICKNESS__;
panel.alignment = "center";
panel.floating = true;
panel.lengthMode = "fit";       // "Ajustar ao conteúdo" (Plasma 6.1+)
panel.hiding = "__HIDING__";
panel.opacity = "translucent";
panel.addWidget(WIDGET);
