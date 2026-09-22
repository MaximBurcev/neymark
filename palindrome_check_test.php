<?php

declare(strict_types=1);

require __DIR__ . '/palindrome_check.php';

$cases = [
    // [входная строка, ожидаемый результат, описание]
    ['А роза упала на лапу Азора', true, 'классический русский палиндром-фраза с пробелами/регистром'],
    ['топот', true, 'простое слово-палиндром'],
    ['Топот', true, 'слово-палиндром с заглавной буквы'],
    ['racecar', true, 'английское слово-палиндром'],
    ['A man, a plan, a canal: Panama', true, 'фраза с пунктуацией и регистром'],
    ['12321', true, 'числовой палиндром'],
    ['12345', false, 'число не палиндром'],
    ['привет', false, 'обычное слово, не палиндром'],
    ['', false, 'пустая строка — не палиндром по определению'],
    ['   ', false, 'строка из одних пробелов — после очистки пусто'],
    ['a', true, 'один символ — всегда палиндром'],
    ['ы', true, 'один кириллический символ'],
    ['Do geese see God?', true, 'фраза с пунктуацией и заглавными буквами'],
    ['Was it a car or a cat I saw?', true, 'фраза с пробелами и пунктуацией'],
    ['No lemon, no melon', true, 'фраза с запятой'],
    ['Hello, World!', false, 'обычная фраза, не палиндром'],
    ['Madam, I\'m Adam', true, 'фраза с апострофом'],
    ['1231', false, 'похоже на палиндром, но нет'],
    ['ab ba', true, 'палиндром с пробелом в середине'],
    ['Nurses run', true, 'фраза, палиндром без учёта регистра и пробела'],
];

$failed = 0;

foreach ($cases as [$input, $expected, $description]) {
    $actual = isPalindrome($input);
    $status = $actual === $expected ? 'OK  ' : 'FAIL';

    if ($actual !== $expected) {
        $failed++;
    }

    printf(
        "[%s] isPalindrome(%s) = %s (ожидалось %s) — %s\n",
        $status,
        var_export($input, true),
        var_export($actual, true),
        var_export($expected, true),
        $description
    );
}

echo "\n" . ($failed === 0 ? 'Все тесты прошли успешно.' : "Провалено тестов: {$failed}") . "\n";
