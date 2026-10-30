<?php
 = getenv('FLAG') ?: 'CTF{offline_docker_flag_example}';
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>Dynamic CTF Challenge</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f172a; color: #f8fafc; text-align: center; padding-top: 80px; }
        .box { background: #1e293b; border-radius: 12px; padding: 40px; display: inline-block; box-shadow: 0 10px 25px rgba(0,0,0,0.5); max-width: 600px; }
        h1 { color: #38bdf8; margin-bottom: 10px; }
        p { color: #94a3b8; font-size: 1.1em; }
        .secret { background: #334155; padding: 15px 25px; border-radius: 6px; font-family: monospace; font-size: 1.3em; color: #4ade80; margin: 20px 0; border: 1px dashed #4ade80; }
        .status { color: #a855f7; font-weight: bold; }
    </style>
</head>
<body>
    <div class="box">
        <h1>Инстанс задания запущен!</h1>
        <p>Каждому участнику выделяется изолированный Docker-контейнер с уникальным портом и динамическим флагом.</p>
        <div class="secret"><?php echo htmlspecialchars(); ?></div>
        <p class="status">Режим: Оффлайн (без доступа к интернету)</p>
    </div>
</body>
</html>
