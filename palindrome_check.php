<?php

declare(strict_types=1);

/**
 * Проверяет, является ли переданный текст палиндромом.
 * Сравнение регистронезависимое, игнорирует пробелы и знаки препинания,
 * корректно работает с UTF-8 (в т.ч. кириллицей).
 */
function isPalindrome(string $text): bool
{
    $normalized = normalizeForPalindromeCheck($text);

    if ($normalized === '') {
        return false;
    }

    $length = mb_strlen($normalized, 'UTF-8');

    for ($i = 0, $j = $length - 1; $i < $j; $i++, $j--) {
        if (mb_substr($normalized, $i, 1, 'UTF-8') !== mb_substr($normalized, $j, 1, 'UTF-8')) {
            return false;
        }
    }

    return true;
}

function normalizeForPalindromeCheck(string $text): string
{
    // Оставляем только буквы и цифры (юникод-режим \p{L}\p{N}), убираем пробелы/пунктуацию/переносы строк
    $cleaned = preg_replace('/[^\p{L}\p{N}]+/u', '', $text);

    return mb_strtolower($cleaned, 'UTF-8');
}
